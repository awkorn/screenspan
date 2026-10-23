import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown over a blocked app: what's blocked, why, until when, and
/// a nudge toward what the user said they'd rather be doing.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName,
             reason: ShieldReason(application: application.token, category: nil, webDomain: nil))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName,
             reason: ShieldReason(application: application.token, category: category.token, webDomain: nil))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain, reason: ShieldReason(application: nil, category: nil, webDomain: webDomain.token))
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain,
             reason: ShieldReason(application: nil, category: category.token, webDomain: webDomain.token))
    }

    private func make(name: String?, reason: ShieldReason) -> ShieldConfiguration {
        let icon = UIImage(systemName: "hourglass",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold))?
            .withTintColor(Palette.red, renderingMode: .alwaysOriginal)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: .white,
            icon: icon,
            title: .init(text: "\(name ?? "This app") is blocked", color: Palette.navy),
            subtitle: .init(text: "\(reason.message)\n\n\(Self.nudge())", color: Palette.muted),
            primaryButtonLabel: .init(text: "Close", color: .white),
            primaryButtonBackgroundColor: Palette.navy
        )
    }

    /// One of the user's own intentions, changing day to day.
    private static func nudge(now: Date = Date()) -> String {
        let intentions = TimeIntention.resolve(
            UserDefaults.appGroup.stringArray(forKey: SharedConstants.UserDefaultsKey.timeIntentions.rawValue))
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        return intentions[day % intentions.count].nudge
    }
}

/// Which of the user's rules is blocking this item. The shield is only told
/// the item, so this matches it against the saved configuration.
private enum ShieldReason {
    case focus(until: Date)
    case schedule(name: String, until: Date)
    case limit(minutes: Int)
    case unknown

    init(application: ApplicationToken?, category: ActivityCategoryToken?, webDomain: WebDomainToken?) {
        let configuration = BlockingConfiguration.load()
        let now = Date()
        func matches(_ selection: FamilyActivitySelection) -> Bool {
            if let application, selection.applicationTokens.contains(application) { return true }
            if let category, selection.categoryTokens.contains(category) { return true }
            if let webDomain, selection.webDomainTokens.contains(webDomain) { return true }
            return false
        }
        if matches(configuration.blockList) {
            if let session = configuration.activeSession(at: now) {
                self = .focus(until: session.end)
                return
            }
            if let schedule = configuration.activeSchedules(at: now).first, let end = schedule.end(after: now) {
                self = .schedule(name: schedule.name, until: end)
                return
            }
        }
        if let limit = configuration.limits.first(where: { $0.isEnabled && matches($0.selection) }) {
            self = .limit(minutes: limit.dailyMinutes)
            return
        }
        self = .unknown
    }

    var message: String {
        switch self {
        case .focus(let end):
            "You're in a focus block until \(end.formatted(date: .omitted, time: .shortened))."
        case .schedule(let name, let end):
            "\(name) is on until \(end.formatted(date: .omitted, time: .shortened))."
        case .limit(let minutes):
            "You've used today's \(Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))). It unlocks at midnight."
        case .unknown:
            "You chose to block this with ScreenSpan."
        }
    }
}

private enum Palette {
    static let navy = UIColor(red: 5 / 255, green: 20 / 255, blue: 37 / 255, alpha: 1)
    static let muted = UIColor(red: 75 / 255, green: 85 / 255, blue: 99 / 255, alpha: 1)
    static let red = UIColor(red: 229 / 255, green: 50 / 255, blue: 45 / 255, alpha: 1)
}

import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown over a blocked app: a calm white pause with the app's life
/// grid, clear block details, and one supportive message. The words live in
/// `BlockScreenCopy`.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName,
             reason: BlockReason(application: application.token, category: nil, webDomain: nil))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName,
             reason: BlockReason(application: application.token, category: category.token, webDomain: nil))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain, reason: BlockReason(application: nil, category: nil, webDomain: webDomain.token))
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain,
             reason: BlockReason(application: nil, category: category.token, webDomain: webDomain.token))
    }

    private func make(name: String?, reason: BlockReason) -> ShieldConfiguration {
        let copy = BlockScreenCopy(appName: name, reason: reason)
        return ShieldConfiguration(
            backgroundBlurStyle: BlockScreenStyle.blur,
            backgroundColor: BlockScreenStyle.background,
            icon: BlockScreenStyle.mark(),
            title: .init(text: copy.title, color: BlockScreenStyle.navy),
            subtitle: .init(text: copy.subtitle, color: BlockScreenStyle.slate),
            primaryButtonLabel: .init(text: copy.button, color: .white),
            primaryButtonBackgroundColor: BlockScreenStyle.navy
        )
    }
}

/// The shield is only told the item, so this matches it against the saved
/// configuration.
private extension BlockReason {
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
}

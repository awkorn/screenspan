import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// One thing that can block apps. Each rule has its own DeviceActivity name
/// and its own ManagedSettings store, so clearing one never lifts another;
/// iOS shields an app if any store blocks it.
enum BlockingRule: Hashable {
    case session
    case schedule(UUID)
    case limit(UUID)
    /// One app in the reduction plan, keyed by `PlannedApp.id`.
    case plan(UUID)

    static let limitEvent = DeviceActivityEvent.Name("dailyLimit")

    /// A planned app's threshold. The name carries its minutes, so the monitor
    /// knows which limit fired when today's and tomorrow's are both watched.
    static func planEvent(minutes: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("planLimit.\(minutes)")
    }

    static func planEventMinutes(_ event: DeviceActivityEvent.Name) -> Int? {
        let parts = event.rawValue.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, parts[0] == "planLimit" else { return nil }
        return Int(parts[1])
    }

    init?(activity: DeviceActivityName) {
        self.init(rawValue: activity.rawValue)
    }

    init?(rawValue: String) {
        if rawValue == "session" { self = .session; return }
        let parts = rawValue.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "schedule": self = .schedule(id)
        case "limit": self = .limit(id)
        case "plan": self = .plan(id)
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .session: "session"
        case .schedule(let id): "schedule.\(id.uuidString)"
        case .limit(let id): "limit.\(id.uuidString)"
        case .plan(let id): "plan.\(id.uuidString)"
        }
    }

    var activityName: DeviceActivityName { DeviceActivityName(rawValue) }

    var store: ManagedSettingsStore { ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue)) }

    func shield(_ selection: FamilyActivitySelection) {
        let store = store
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    func clear() {
        store.clearAllSettings()
    }

    /// Every rule the configuration can have shields in.
    static func all(in configuration: BlockingConfiguration) -> [BlockingRule] {
        [.session] + configuration.schedules.map { .schedule($0.id) } + configuration.limits.map { .limit($0.id) }
            + configuration.plan.apps.map { .plan($0.id) }
    }
}

import FamilyControls
import Foundation

/// One app the user is planning to cut back on, before the plan starts. The
/// starting point is the user's entry, read off their own report.
struct PlanDraftItem: Codable, Identifiable, Equatable {
    var id = UUID()
    /// A single app, category, or website.
    var selection: FamilyActivitySelection
    /// Nil until the user sets it; there's no measured number to default to.
    var baselineMinutes: Int?
    /// Nil for the default, half the starting point.
    var targetMinutes: Int?

    /// The course this item would start at `start`.
    func course(start: Date) -> ReductionCourse? {
        guard let baselineMinutes, baselineMinutes >= ReductionCourse.minimumBaselineMinutes else { return nil }
        return ReductionCourse(baselineMinutes: baselineMinutes, targetMinutes: targetMinutes, start: start)
    }

    /// One item per token in `selection`, keeping entries for tokens already in `existing`.
    static func items(from selection: FamilyActivitySelection, keeping existing: [PlanDraftItem]) -> [PlanDraftItem] {
        var singles: [FamilyActivitySelection] = []
        for token in selection.applicationTokens {
            var single = FamilyActivitySelection()
            single.applicationTokens = [token]
            singles.append(single)
        }
        for token in selection.categoryTokens {
            var single = FamilyActivitySelection()
            single.categoryTokens = [token]
            singles.append(single)
        }
        for token in selection.webDomainTokens {
            var single = FamilyActivitySelection()
            single.webDomainTokens = [token]
            singles.append(single)
        }
        return singles.map { single in
            existing.first { $0.selection == single } ?? PlanDraftItem(selection: single)
        }
    }

    static func load(from defaults: UserDefaults = .appGroup) -> [PlanDraftItem] {
        guard let data = defaults.data(forKey: SharedConstants.UserDefaultsKey.reductionPlanDraft.rawValue),
              let items = try? JSONDecoder().decode([PlanDraftItem].self, from: data)
        else { return [] }
        return items
    }

    static func save(_ items: [PlanDraftItem], to defaults: UserDefaults = .appGroup) {
        let key = SharedConstants.UserDefaultsKey.reductionPlanDraft.rawValue
        guard !items.isEmpty, let data = try? JSONEncoder().encode(items) else { return defaults.removeObject(forKey: key) }
        defaults.set(data, forKey: key)
    }
}

extension FamilyActivitySelection {
    /// Apps, categories, and websites in this selection, counted together.
    var tokenCount: Int {
        applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }
}

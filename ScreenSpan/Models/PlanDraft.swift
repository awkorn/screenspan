import FamilyControls
import Foundation
import Observation

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

/// The plan being set up, in onboarding or later from Blocking. When the user
/// already has a plan, this adds to it: apps already planned are left out and
/// only the remaining room can be picked.
@Observable
final class PlanDraftModel {
    var items: [PlanDraftItem]
    /// Apps already in the plan, when adding to one.
    private(set) var existing: [PlannedApp]
    var currentAge: Int

    init(existing: [PlannedApp] = [], currentAge: Int = AppGroupManager.shared.currentAge) {
        self.existing = existing
        self.currentAge = currentAge
        let planned = existing.map(\.selection)
        items = PlanDraftItem.load().filter { !planned.contains($0.selection) }
    }

    var isAdding: Bool { !existing.isEmpty }
    /// How many more apps fit in the plan.
    var room: Int { max(ReductionPlan.maximumApps - existing.count, 0) }

    /// Every picked app has a starting point the plan can step down from.
    var isReady: Bool {
        !items.isEmpty && items.allSatisfy { $0.course(start: Date()) != nil }
    }

    /// Takes the picker's selection, one item per app, dropping apps already
    /// planned. Returns false, changing nothing, when it's more than fits.
    @discardableResult
    func setSelection(_ selection: FamilyActivitySelection) -> Bool {
        let planned = existing.map(\.selection)
        let picked = PlanDraftItem.items(from: selection, keeping: items).filter { !planned.contains($0.selection) }
        guard picked.count <= room else { return false }
        items = picked
        save()
        return true
    }

    func save() {
        PlanDraftItem.save(items)
    }

    func courses(start: Date) -> [ReductionCourse] {
        items.compactMap { $0.course(start: start) }
    }

    /// Lifetime time back once every picked app reaches its target.
    var yearsBackAtTarget: Double {
        courses(start: Date()).regainedAtTarget(currentAge: currentAge, targetAge: SharedConstants.DefaultValues.targetAge).yearsReclaimed
    }

    /// Starts the picked apps' limits at the next midnight and clears the draft.
    @MainActor
    func start(with blocking: BlockingService) {
        for item in items {
            guard let baseline = item.baselineMinutes else { continue }
            blocking.addToPlan(item.selection, baselineMinutes: baseline, targetMinutes: item.targetMinutes)
        }
        items = []
        PlanDraftItem.save([])
    }
}

extension FamilyActivitySelection {
    /// Apps, categories, and websites in this selection, counted together.
    var tokenCount: Int {
        applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }
}

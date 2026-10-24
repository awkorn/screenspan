import CoreGraphics
import Foundation

/// Something the user said they'd rather do with their time. User-entered;
/// the onboarding reveal converts a year of phone time into these.
enum TimeIntention: String, CaseIterable, Identifiable, Sendable {
    case read, language, exercise, family, sleep, create, travel, outdoors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .read: "Read more"
        case .language: "Learn a language"
        case .exercise: "Get fit"
        case .family: "Family & friends"
        case .sleep: "Sleep better"
        case .create: "Make something"
        case .travel: "Travel"
        case .outdoors: "Be outside"
        }
    }

    var icon: String {
        switch self {
        case .read: "book"
        case .language: "character.bubble"
        case .exercise: "figure.run"
        case .family: "person.2"
        case .sleep: "moon.zzz"
        case .create: "paintbrush.pointed"
        case .travel: "airplane"
        case .outdoors: "leaf"
        }
    }

    /// Ways to make room for this at a pace a real week can hold, most
    /// ambitious first. The reveal steps down a tier when the user's phone
    /// time can't cover all their picks at once.
    var habits: [Habit] {
        switch self {
        case .read: [
            Habit("A book every week", hoursPerYear: 52 * 6), // ~6 hours a novel at adult reading speed
            Habit("A book every two weeks", hoursPerYear: 26 * 6),
            Habit("A book every month", hoursPerYear: 12 * 6)]
        case .language: [
            // CEFR B1, "conversational", is ~350–400 guided hours.
            Habit("Conversational in a new language within a year", hoursPerYear: 365), // an hour a day
            Habit("Conversational in a new language within two years", hoursPerYear: 365 / 2),
            Habit("15 minutes a day on a new language", hoursPerYear: 365 / 4)]
        case .exercise: [
            Habit("A 45-minute workout, five days a week", hoursPerYear: 52 * 5 * 0.75),
            Habit("A 45-minute workout, three days a week", hoursPerYear: 52 * 3 * 0.75),
            Habit("A 45-minute workout, twice a week", hoursPerYear: 52 * 2 * 0.75)]
        case .family: [
            Habit("Dinner with people you love, every night", hoursPerYear: 365 * 1.5),
            Habit("A long dinner with people you love, twice a week", hoursPerYear: 52 * 2 * 2),
            Habit("A long dinner with people you love, every week", hoursPerYear: 52 * 2)]
        case .sleep: [
            Habit("An extra hour of sleep, every night", hoursPerYear: 365),
            Habit("An extra 30 minutes of sleep, every night", hoursPerYear: 365 / 2),
            Habit("An extra 15 minutes of sleep, every night", hoursPerYear: 365 / 4)]
        case .create: [
            Habit("One full day a week on something of your own", hoursPerYear: 52 * 8),
            Habit("One evening a week on something of your own", hoursPerYear: 52 * 3),
            Habit("An hour a week on something of your own", hoursPerYear: 52)]
        case .travel: [
            // Two waking days, since phone time is waking time.
            Habit("A weekend away every month", hoursPerYear: 12 * 32),
            Habit("A weekend away every season", hoursPerYear: 4 * 32),
            Habit("A weekend away every year", hoursPerYear: 32)]
        case .outdoors: [
            Habit("A half day outside every weekend", hoursPerYear: 52 * 4),
            Habit("A half day outside every other weekend", hoursPerYear: 26 * 4),
            Habit("A half day outside every month", hoursPerYear: 12 * 4)]
        }
    }

    static let defaults: [TimeIntention] = [.read, .language, .sleep]

    /// Stored selection, in display order, falling back to defaults.
    static func resolve(_ rawValues: [String]?) -> [TimeIntention] {
        let chosen = Set(rawValues ?? [])
        let picked = allCases.filter { chosen.contains($0.rawValue) }
        return picked.isEmpty ? defaults : picked
    }
}

/// One concrete way to spend time on an intention, with what it costs a year.
struct Habit: Equatable, Sendable {
    let title: String
    let hoursPerYear: Double

    init(_ title: String, hoursPerYear: Double) {
        self.title = title
        self.hoursPerYear = hoursPerYear
    }
}

/// What a year of phone time could pay for instead: one habit per intention.
struct HabitPlan: Equatable {
    struct Item: Equatable {
        let intention: TimeIntention
        let habit: Habit
    }

    /// Hours a year at the user's daily pace.
    let budgetHours: Double
    let items: [Item]
    /// All habits fit in the budget at once. Otherwise each fits on its own.
    let fitsTogether: Bool

    var habits: [Habit] { items.map(\.habit) }
    var spareHours: Double { fitsTogether ? max(budgetHours - habits.map(\.hoursPerYear).reduce(0, +), 0) : 0 }

    /// Starts every intention at its most ambitious habit and steps down the
    /// costliest until they fit together. If even the lightest don't, each
    /// intention gets the most ambitious habit that fits alone, and those
    /// that can't fit are left out.
    init(intentions: [TimeIntention], dailyHours: Double) {
        let budget = dailyHours.isFinite ? min(max(dailyHours, 0), 24) * 365 : 0
        budgetHours = budget
        var tiers = Array(repeating: 0, count: intentions.count)
        func cost(_ index: Int) -> Double { intentions[index].habits[tiers[index]].hoursPerYear }
        while tiers.indices.map(cost).reduce(0, +) > budget,
              let costliest = tiers.indices
                .filter({ tiers[$0] < intentions[$0].habits.count - 1 })
                .max(by: { cost($0) < cost($1) }) {
            tiers[costliest] += 1
        }
        if !intentions.isEmpty, tiers.indices.map(cost).reduce(0, +) <= budget {
            items = tiers.indices.map { Item(intention: intentions[$0], habit: intentions[$0].habits[tiers[$0]]) }
            fitsTogether = true
        } else {
            items = intentions.compactMap { intention in
                intention.habits.first { $0.hoursPerYear <= budget }.map { Item(intention: intention, habit: $0) }
            }
            fitsTogether = false
        }
    }
}

/// Plain numbers behind the onboarding reveal.
enum RevealMath {
    /// Full 24-hour days per year at a daily pace.
    static func daysPerYear(dailyHours: Double) -> Double {
        guard dailyHours.isFinite, dailyHours > 0 else { return 0 }
        return min(dailyHours, 24) * 365 / 24
    }

    /// Positive when the user guessed less than they actually use.
    static func underestimateHours(guess: Double, actual: Double) -> Double {
        actual - guess
    }

    /// Daily targets worth showing as "what you could get back": those
    /// meaningfully below the current pace.
    static func potentialTargets(currentDailyHours: Double, candidates: [Double] = [1, 2, 3]) -> [Double] {
        candidates.filter { $0 <= currentDailyHours - 0.25 }
    }
}

/// The layout contract between the host and the report. The report is one
/// tall view: five panels of equal height, then one short row per goal value.
/// The host sizes the report and moves a window over it; it never reads it.
enum OnboardingRevealLayout {
    static let panelCount = 5
    static let goalRowHeight: CGFloat = 132
    static let goalValues: [Double] = Array(stride(from: 0.5, through: 8, by: 0.25))

    static func totalHeight(panelHeight: CGFloat) -> CGFloat {
        panelHeight * CGFloat(panelCount) + goalRowHeight * CGFloat(goalValues.count)
    }

    static func panelOffset(_ panel: Int, panelHeight: CGFloat) -> CGFloat {
        CGFloat(min(max(panel, 0), panelCount - 1)) * panelHeight
    }

    static func goalOffset(_ goalHours: Double, panelHeight: CGFloat) -> CGFloat {
        panelHeight * CGFloat(panelCount) + CGFloat(goalIndex(goalHours)) * goalRowHeight
    }

    static func goalIndex(_ goalHours: Double) -> Int {
        let index = Int(((goalHours - goalValues[0]) / 0.25).rounded())
        return min(max(index, 0), goalValues.count - 1)
    }
}

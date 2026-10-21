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

    /// Hours one unit takes. Stated with every conversion shown to the user.
    var hoursPerUnit: Double {
        switch self {
        case .read: 6          // a typical novel at average adult reading speed
        case .language: 700    // FSI estimate to working proficiency in an easier language
        case .exercise: 0.75   // one 45-minute workout
        case .family: 2        // one long dinner
        case .sleep: 8         // one full night
        case .create: 100      // one substantial side project
        case .travel: 48       // one weekend away
        case .outdoors: 3      // one half-day hike
        }
    }

    func unitLabel(count: Double) -> String {
        let one = count.rounded() == 1
        switch self {
        case .read: return one ? "book" : "books"
        case .language: return one ? "new language" : "new languages"
        case .exercise: return one ? "workout" : "workouts"
        case .family: return one ? "long dinner together" : "long dinners together"
        case .sleep: return one ? "full night of sleep" : "full nights of sleep"
        case .create: return one ? "side project" : "side projects"
        case .travel: return one ? "weekend trip" : "weekend trips"
        case .outdoors: return one ? "half-day hike" : "half-day hikes"
        }
    }

    var assumption: String {
        switch self {
        case .read: "6 hours per book"
        case .language: "700 hours per language"
        case .exercise: "45 minutes per workout"
        case .family: "2 hours per dinner"
        case .sleep: "8 hours per night"
        case .create: "100 hours per project"
        case .travel: "48 hours per trip"
        case .outdoors: "3 hours per hike"
        }
    }

    /// Units that a year at `dailyHours` would cover.
    func unitsPerYear(dailyHours: Double) -> Double {
        guard dailyHours.isFinite, dailyHours > 0 else { return 0 }
        return min(dailyHours, 24) * 365 / hoursPerUnit
    }

    static let defaults: [TimeIntention] = [.read, .language, .sleep]

    /// Stored selection, in display order, falling back to defaults.
    static func resolve(_ rawValues: [String]?) -> [TimeIntention] {
        let chosen = Set(rawValues ?? [])
        let picked = allCases.filter { chosen.contains($0.rawValue) }
        return picked.isEmpty ? defaults : picked
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

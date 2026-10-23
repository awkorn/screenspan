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

    /// A short suggestion on the block screen, in the user's own terms.
    var nudge: String {
        switch self {
        case .read: "You wanted to read more. A few pages instead?"
        case .language: "You wanted to learn a language. Ten minutes of practice?"
        case .exercise: "You wanted to get fit. How about a quick walk?"
        case .family: "You wanted more time with people you love. Call one of them?"
        case .sleep: "You wanted to sleep better. Put the phone down for the night?"
        case .create: "You wanted to make something. Pick it back up?"
        case .travel: "You wanted to travel. Every hour back gets you closer."
        case .outdoors: "You wanted to be outside. Step out for a minute?"
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

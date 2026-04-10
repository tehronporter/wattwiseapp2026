import Foundation

// MARK: - XP Constants

enum WWGamification {
    enum XP {
        static let lessonFirstComplete = 50
        static let quizAttempt         = 10
        static let quizPassed          = 30   // score >= 0.70
        static let quizPerfect         = 60   // score == 1.0 (bonus, stacks with passed)
        static let xpPerLevel          = 500
    }

    enum LevelLabel {
        static func label(for level: Int) -> String {
            switch level {
            case 0...2: return "Apprentice"
            case 3...5: return "Journeyman"
            case 6...9: return "Master"
            default:    return "Expert"
            }
        }
    }
}

// MARK: - XP Source

enum XPSource: String {
    case lessonComplete = "lesson_complete"
    case quizAttempt    = "quiz_attempt"
    case quizPassed     = "quiz_passed"
    case quizPerfect    = "quiz_perfect"
}

// MARK: - XP Award Result

struct XPAward {
    let earned: Int
    let newTotal: Int
    let leveledUp: Bool
    let newLevel: Int
}

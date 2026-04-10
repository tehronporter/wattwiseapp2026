import Foundation
import Observation

// MARK: - XPStore

@Observable
@MainActor
final class XPStore {
    static let shared = XPStore()

    private(set) var totalXP: Int = 0

    private let defaults = UserDefaults.standard
    private let storageKey = "ww_total_xp"

    private init() {
        totalXP = defaults.integer(forKey: storageKey)
    }

    // MARK: - Level

    var currentLevel: Int {
        totalXP / WWGamification.XP.xpPerLevel
    }

    var progressToNextLevel: Double {
        let remainder = totalXP % WWGamification.XP.xpPerLevel
        return Double(remainder) / Double(WWGamification.XP.xpPerLevel)
    }

    var levelLabel: String {
        WWGamification.LevelLabel.label(for: currentLevel)
    }

    // MARK: - Award

    @discardableResult
    func award(_ amount: Int, source: XPSource) -> XPAward {
        let oldLevel = currentLevel
        totalXP += amount
        defaults.set(totalXP, forKey: storageKey)
        let newLevel = currentLevel
        return XPAward(
            earned: amount,
            newTotal: totalXP,
            leveledUp: newLevel > oldLevel,
            newLevel: newLevel
        )
    }

    // MARK: - XP Calculation helpers

    static func xpForQuiz(score: Double) -> Int {
        var xp = WWGamification.XP.quizAttempt
        if score >= 0.7  { xp += WWGamification.XP.quizPassed }
        if score == 1.0  { xp += WWGamification.XP.quizPerfect }
        return xp
    }
}

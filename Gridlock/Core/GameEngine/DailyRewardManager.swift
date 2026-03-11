import Foundation
import Combine
import os.log

// MARK: - Daily Reward Manager
// Handles daily login rewards, streak bonuses, and engagement hooks

final class DailyRewardManager: ObservableObject {
    static let shared = DailyRewardManager()

    @Published private(set) var hasUncollectedReward: Bool = false
    @Published private(set) var todayReward: DailyReward?
    @Published private(set) var showDailyPopup: Bool = false

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.gridlock.app", category: "DailyReward")

    private let lastCollectedDateKey = "dailyRewardLastCollected"
    private let totalDaysCollectedKey = "dailyRewardTotalDays"

    private init() {
        checkForReward()
    }

    // MARK: - Daily Reward Definition

    struct DailyReward {
        let dayNumber: Int
        let title: String
        let emoji: String
        let powerUps: [(PowerUpType, Int)]
        let bonusDescription: String

        static func forDay(_ day: Int) -> DailyReward {
            // Cycle through a 7-day reward schedule
            let cycleDay = ((day - 1) % 7) + 1

            switch cycleDay {
            case 1:
                return DailyReward(dayNumber: day, title: "Welcome Back!", emoji: "🎲",
                                   powerUps: [(.bomb, 1)], bonusDescription: "1 Bomb")
            case 2:
                return DailyReward(dayNumber: day, title: "Day 2 Bonus", emoji: "⚡",
                                   powerUps: [(.lineBlast, 1)], bonusDescription: "1 Line Blast")
            case 3:
                return DailyReward(dayNumber: day, title: "Midweek Boost", emoji: "🔄",
                                   powerUps: [(.bomb, 1), (.undo, 1)], bonusDescription: "1 Bomb + 1 Undo")
            case 4:
                return DailyReward(dayNumber: day, title: "Keep Going!", emoji: "💪",
                                   powerUps: [(.shuffle, 1)], bonusDescription: "1 Shuffle")
            case 5:
                return DailyReward(dayNumber: day, title: "Almost There!", emoji: "🌟",
                                   powerUps: [(.bomb, 1), (.lineBlast, 1)], bonusDescription: "1 Bomb + 1 Line Blast")
            case 6:
                return DailyReward(dayNumber: day, title: "Six Day Hero", emoji: "🏅",
                                   powerUps: [(.bomb, 2), (.undo, 1)], bonusDescription: "2 Bombs + 1 Undo")
            case 7:
                return DailyReward(dayNumber: day, title: "Weekly Jackpot!", emoji: "🎰",
                                   powerUps: [(.bomb, 2), (.lineBlast, 1), (.undo, 1), (.shuffle, 1)],
                                   bonusDescription: "Full Power-Up Pack!")
            default:
                return DailyReward(dayNumber: day, title: "Daily Reward", emoji: "🎁",
                                   powerUps: [(.bomb, 1)], bonusDescription: "1 Bomb")
            }
        }
    }

    // MARK: - Check & Collect

    func checkForReward() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastCollected = defaults.object(forKey: lastCollectedDateKey) as? Date {
            let lastDay = calendar.startOfDay(for: lastCollected)
            if calendar.isDate(today, inSameDayAs: lastDay) {
                // Already collected today
                hasUncollectedReward = false
                return
            }
        }

        // Reward available!
        let totalDays = defaults.integer(forKey: totalDaysCollectedKey) + 1
        todayReward = DailyReward.forDay(totalDays)
        hasUncollectedReward = true
        showDailyPopup = true
    }

    func collectReward(powerUpSystem: PowerUpSystem) -> DailyReward? {
        guard hasUncollectedReward, let reward = todayReward else { return nil }

        // Award power-ups
        for (type, count) in reward.powerUps {
            for _ in 0..<count {
                powerUpSystem.earn(type, reason: "daily reward day \(reward.dayNumber)")
            }
        }

        // Record collection
        let totalDays = defaults.integer(forKey: totalDaysCollectedKey) + 1
        defaults.set(totalDays, forKey: totalDaysCollectedKey)
        defaults.set(Date(), forKey: lastCollectedDateKey)

        hasUncollectedReward = false
        showDailyPopup = false

        logger.info("Daily reward collected: day \(reward.dayNumber) - \(reward.bonusDescription)")

        // Record streak
        _ = StreakManager.shared.recordGamePlayed()

        return reward
    }

    func dismissPopup() {
        showDailyPopup = false
    }

    // MARK: - Engagement Data

    var daysPlayed: Int {
        defaults.integer(forKey: totalDaysCollectedKey)
    }

    var streakInfo: String {
        let streak = StreakManager.shared.currentStreak
        if streak > 1 {
            return "\(streak)-day streak! 🔥"
        } else if StreakManager.shared.isStreakAtRisk {
            return "Play today to keep your streak!"
        }
        return ""
    }

    var nextRewardPreview: String {
        let nextDay = daysPlayed + 1
        let reward = DailyReward.forDay(nextDay)
        return "Tomorrow: \(reward.emoji) \(reward.bonusDescription)"
    }
}

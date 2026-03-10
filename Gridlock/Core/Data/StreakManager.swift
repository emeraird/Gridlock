import Foundation
import os.log

// MARK: - Streak Reward

struct StreakReward {
    let day: Int
    let description: String
    let powerUps: [PowerUpType: Int]
    let themeUnlock: String?

    static let milestones: [StreakReward] = [
        StreakReward(day: 1, description: "1 Bomb", powerUps: [.bomb: 1], themeUnlock: nil),
        StreakReward(day: 3, description: "1 Line Blast", powerUps: [.lineBlast: 1], themeUnlock: nil),
        StreakReward(day: 5, description: "1 Shuffle!", powerUps: [.shuffle: 1], themeUnlock: nil),
        StreakReward(day: 7, description: "1 of each power-up!", powerUps: [.bomb: 1, .lineBlast: 1, .undo: 1, .shuffle: 1], themeUnlock: nil),
        StreakReward(day: 14, description: "Streak Master badge", powerUps: [:], themeUnlock: nil),
        StreakReward(day: 30, description: "Golden Grid theme!", powerUps: [.bomb: 1, .lineBlast: 1, .undo: 1, .shuffle: 1], themeUnlock: "golden"),
    ]
}

// MARK: - Streak Manager

final class StreakManager: ObservableObject {
    static let shared = StreakManager()

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var lastPlayDate: Date?
    @Published private(set) var playedToday: Bool = false

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.gridlock.app", category: "StreakManager")

    private enum Keys {
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let lastPlayDate = "lastPlayDate"
    }

    private init() {
        currentStreak = defaults.integer(forKey: Keys.currentStreak)
        longestStreak = defaults.integer(forKey: Keys.longestStreak)
        lastPlayDate = defaults.object(forKey: Keys.lastPlayDate) as? Date
        checkStreakStatus()
    }

    // MARK: - Streak Logic

    /// Call when a game is completed
    func recordGamePlayed() -> StreakReward? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = lastPlayDate {
            let lastDay = calendar.startOfDay(for: lastDate)

            if calendar.isDate(today, inSameDayAs: lastDay) {
                // Already played today
                playedToday = true
                return nil
            }

            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                // Consecutive day — extend streak
                currentStreak += 1
            } else {
                // Streak broken
                logger.info("Streak broken. Was \(self.currentStreak) days, missed \(daysDiff - 1) days")
                currentStreak = 1
            }
        } else {
            // First ever play
            currentStreak = 1
        }

        playedToday = true
        lastPlayDate = Date()

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        save()

        // Check for milestone reward
        let reward = StreakReward.milestones.first { $0.day == currentStreak }
        if let reward = reward {
            logger.info("Streak milestone: day \(self.currentStreak) - \(reward.description)")
        }

        return reward
    }

    /// Check if streak is still valid (call on app launch)
    func checkStreakStatus() {
        guard let lastDate = lastPlayDate else {
            playedToday = false
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)

        playedToday = calendar.isDate(today, inSameDayAs: lastDay)

        let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysDiff > 1 {
            // Streak is broken but don't reset until they play again
            logger.info("Streak at risk: \(daysDiff) days since last play")
        }
    }

    /// Whether the player needs to play today to maintain their streak
    var isStreakAtRisk: Bool {
        guard currentStreak > 0, !playedToday else { return false }
        return true
    }

    /// Next milestone the player is working toward
    var nextMilestone: StreakReward? {
        StreakReward.milestones.first { $0.day > currentStreak }
    }

    /// Days until next milestone
    var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next.day - currentStreak
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(currentStreak, forKey: Keys.currentStreak)
        defaults.set(longestStreak, forKey: Keys.longestStreak)
        defaults.set(lastPlayDate, forKey: Keys.lastPlayDate)
    }
}

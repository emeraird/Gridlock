import Foundation
import os.log

// MARK: - Achievement

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    var isUnlocked: Bool
    var unlockedDate: Date?

    static let all: [Achievement] = [
        Achievement(id: "first_1000", title: "Getting Started", description: "Score 1,000 points", iconName: "star.fill", isUnlocked: false),
        Achievement(id: "score_5000", title: "Rising Star", description: "Score 5,000 points", iconName: "star.circle.fill", isUnlocked: false),
        Achievement(id: "score_10000", title: "Puzzle Master", description: "Score 10,000 in one game", iconName: "crown.fill", isUnlocked: false),
        Achievement(id: "combo_5", title: "Combo King", description: "Reach a 5x combo chain", iconName: "bolt.fill", isUnlocked: false),
        Achievement(id: "combo_10", title: "Combo Legend", description: "Reach a 10x combo chain", iconName: "bolt.circle.fill", isUnlocked: false),
        Achievement(id: "clear_4", title: "Quadra Clear", description: "Clear 4 lines at once", iconName: "square.grid.4x3.fill", isUnlocked: false),
        Achievement(id: "games_10", title: "Dedicated Player", description: "Play 10 games", iconName: "gamecontroller.fill", isUnlocked: false),
        Achievement(id: "games_100", title: "Gridlock Addict", description: "Play 100 games", iconName: "heart.fill", isUnlocked: false),
        Achievement(id: "streak_7", title: "Week Warrior", description: "7-day play streak", iconName: "flame.fill", isUnlocked: false),
        Achievement(id: "streak_30", title: "Monthly Master", description: "30-day play streak", iconName: "flame.circle.fill", isUnlocked: false),
        Achievement(id: "lines_100", title: "Line Sweeper", description: "Clear 100 total lines", iconName: "line.3.horizontal", isUnlocked: false),
        Achievement(id: "lines_1000", title: "Line Destroyer", description: "Clear 1,000 total lines", iconName: "line.3.horizontal.decrease.circle.fill", isUnlocked: false),
        Achievement(id: "first_powerup", title: "Power Player", description: "Use your first power-up", iconName: "sparkles", isUnlocked: false),
        Achievement(id: "daily_3star", title: "Perfect Day", description: "Get 3 stars on a daily challenge", iconName: "sun.max.fill", isUnlocked: false),
    ]
}

// MARK: - Statistics Tracker

final class StatisticsTracker: ObservableObject {
    static let shared = StatisticsTracker()

    @Published var achievements: [Achievement] = []

    private let defaults = UserDefaults.standard
    private let achievementKey = "unlockedAchievements"
    private let logger = Logger(subsystem: "com.gridlock.app", category: "Statistics")

    // Session stats
    @Published var todayHighScore: Int = 0
    @Published var todayGamesPlayed: Int = 0

    private init() {
        loadAchievements()
        loadTodayStats()
    }

    // MARK: - Achievements

    private func loadAchievements() {
        let unlocked = Set(defaults.stringArray(forKey: achievementKey) ?? [])
        achievements = Achievement.all.map { achievement in
            var a = achievement
            a.isUnlocked = unlocked.contains(a.id)
            return a
        }
    }

    func checkAchievements(
        score: Int,
        combo: Int,
        linesAtOnce: Int,
        totalGames: Int,
        totalLines: Int,
        streak: Int,
        usedPowerUp: Bool,
        dailyStars: Int
    ) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []

        let checks: [(String, Bool)] = [
            ("first_1000", score >= 1000),
            ("score_5000", score >= 5000),
            ("score_10000", score >= 10000),
            ("combo_5", combo >= 5),
            ("combo_10", combo >= 10),
            ("clear_4", linesAtOnce >= 4),
            ("games_10", totalGames >= 10),
            ("games_100", totalGames >= 100),
            ("streak_7", streak >= 7),
            ("streak_30", streak >= 30),
            ("lines_100", totalLines >= 100),
            ("lines_1000", totalLines >= 1000),
            ("first_powerup", usedPowerUp),
            ("daily_3star", dailyStars >= 3),
        ]

        for (id, condition) in checks {
            if condition, let index = achievements.firstIndex(where: { $0.id == id && !$0.isUnlocked }) {
                achievements[index].isUnlocked = true
                achievements[index].unlockedDate = Date()
                newlyUnlocked.append(achievements[index])
            }
        }

        if !newlyUnlocked.isEmpty {
            saveAchievements()
            for a in newlyUnlocked {
                logger.info("Achievement unlocked: \(a.title)")
            }
        }

        return newlyUnlocked
    }

    private func saveAchievements() {
        let unlocked = achievements.filter(\.isUnlocked).map(\.id)
        defaults.set(unlocked, forKey: achievementKey)
    }

    // MARK: - Today Stats

    private func loadTodayStats() {
        let today = Calendar.current.startOfDay(for: Date())
        let savedDate = defaults.object(forKey: "todayStatsDate") as? Date ?? .distantPast
        if Calendar.current.isDate(today, inSameDayAs: savedDate) {
            todayHighScore = defaults.integer(forKey: "todayHighScore")
            todayGamesPlayed = defaults.integer(forKey: "todayGamesPlayed")
        } else {
            todayHighScore = 0
            todayGamesPlayed = 0
            defaults.set(today, forKey: "todayStatsDate")
        }
    }

    func recordTodayGame(score: Int) {
        todayGamesPlayed += 1
        if score > todayHighScore {
            todayHighScore = score
        }
        defaults.set(todayHighScore, forKey: "todayHighScore")
        defaults.set(todayGamesPlayed, forKey: "todayGamesPlayed")
    }

    var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var totalCount: Int {
        achievements.count
    }
}

import SwiftUI

struct StatsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var progress = UserProgressManager.shared
    @StateObject private var stats = StatisticsTracker.shared
    @StateObject private var streak = StreakManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Overview
                Section("Overview") {
                    StatRow(label: "High Score", value: "\(progress.highScore)")
                    StatRow(label: "Games Played", value: "\(progress.totalGamesPlayed)")
                    StatRow(label: "Lines Cleared", value: "\(progress.totalLinesCleared)")
                    StatRow(label: "Blocks Placed", value: "\(progress.totalBlocksPlaced)")
                    StatRow(label: "Longest Combo", value: "\(progress.longestCombo)x")
                }

                // Today
                Section("Today") {
                    StatRow(label: "Today's High Score", value: "\(stats.todayHighScore)")
                    StatRow(label: "Games Today", value: "\(stats.todayGamesPlayed)")
                }

                // Streaks
                Section("Streaks") {
                    StatRow(label: "Current Streak", value: "\(streak.currentStreak) days",
                            icon: "flame.fill", iconColor: .orange)
                    StatRow(label: "Longest Streak", value: "\(streak.longestStreak) days")
                }

                // Time
                Section("Time") {
                    StatRow(label: "Total Time Played", value: formatDuration(progress.totalTimePlayed))
                    if progress.totalGamesPlayed > 0 {
                        StatRow(label: "Avg per Game",
                                value: formatDuration(progress.totalTimePlayed / Double(progress.totalGamesPlayed)))
                    }
                }

                // Achievements
                Section("Achievements (\(stats.unlockedCount)/\(stats.totalCount))") {
                    ForEach(stats.achievements) { achievement in
                        HStack(spacing: 12) {
                            Image(systemName: achievement.iconName)
                                .font(.system(size: 20))
                                .foregroundColor(achievement.isUnlocked ? .yellow : .gray)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                                Text(achievement.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if achievement.isUnlocked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .opacity(achievement.isUnlocked ? 1.0 : 0.5)
                    }
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .secondary

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }
            Text(label)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

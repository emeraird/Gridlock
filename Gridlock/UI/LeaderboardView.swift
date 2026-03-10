import SwiftUI
import GameKit

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isAuthenticated = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isAuthenticated {
                    // Game Center leaderboard will be shown via GKGameCenterViewController
                    Text("Loading leaderboard...")
                        .foregroundColor(.secondary)
                        .onAppear {
                            showGameCenterLeaderboard()
                        }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)

                        Text("Sign in to Game Center")
                            .font(.headline)

                        Text("Connect to Game Center to see leaderboards and compete with friends.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("Sign In") {
                            authenticateGameCenter()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    private func authenticateGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let _ = viewController {
                // Present the Game Center sign-in view controller
                // TODO: Present via UIKit
            } else if GKLocalPlayer.local.isAuthenticated {
                isAuthenticated = true
            }
        }
    }

    private func showGameCenterLeaderboard() {
        // TODO: Present GKGameCenterViewController
    }

    // MARK: - Static Helpers

    static func submitScore(_ score: Int) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                   leaderboardIDs: ["gridlock.highscore"]) { error in
            if let error = error {
                print("Leaderboard submit error: \(error.localizedDescription)")
            }
        }
    }

    static func reportAchievement(_ id: String, percentComplete: Double = 100) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("Achievement report error: \(error.localizedDescription)")
            }
        }
    }
}

import Foundation
import Combine
import os.log

// MARK: - Session Manager
// Tracks session-level stats and provides "one more game" hooks

final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published private(set) var sessionGamesPlayed: Int = 0
    @Published private(set) var sessionHighScore: Int = 0
    @Published private(set) var sessionTotalScore: Int = 0
    @Published private(set) var sessionStartTime: Date = Date()
    @Published private(set) var sessionBestCombo: Int = 0
    @Published private(set) var sessionLinesCleared: Int = 0
    @Published private(set) var consecutiveLosses: Int = 0
    @Published private(set) var isOnHotStreak: Bool = false

    private let logger = Logger(subsystem: "com.gridlock.app", category: "SessionManager")
    private var lastGameScore: Int = 0
    private var scoresTrending: [Int] = []

    private init() {}

    // MARK: - Game Events

    func onGameStart() {
        sessionGamesPlayed += 1
        logger.debug("Session game \(self.sessionGamesPlayed) started")
    }

    func onGameEnd(score: Int, linesCleared: Int, bestCombo: Int) {
        lastGameScore = score
        sessionTotalScore += score
        sessionLinesCleared += linesCleared

        if score > sessionHighScore {
            sessionHighScore = score
        }
        if bestCombo > sessionBestCombo {
            sessionBestCombo = bestCombo
        }

        // Track score trend for hot streak detection
        scoresTrending.append(score)
        if scoresTrending.count > 5 {
            scoresTrending.removeFirst()
        }

        // Detect trends
        updateStreakStatus(score: score)

        logger.info("Session game ended: score=\(score), total=\(self.sessionTotalScore), games=\(self.sessionGamesPlayed)")
    }

    private func updateStreakStatus(score: Int) {
        if score < 200 {
            consecutiveLosses += 1
            isOnHotStreak = false
        } else {
            consecutiveLosses = 0
        }

        // Hot streak: 3 consecutive games with improving scores
        if scoresTrending.count >= 3 {
            let last3 = Array(scoresTrending.suffix(3))
            if last3[2] > last3[1] && last3[1] > last3[0] {
                isOnHotStreak = true
            } else {
                isOnHotStreak = false
            }
        }
    }

    // MARK: - Session Nudge Messages

    var gameOverNudge: String? {
        // Mercy for struggling players
        if consecutiveLosses >= 3 {
            return "Tip: Start with small pieces to keep the board open!"
        }

        // Hot streak encouragement
        if isOnHotStreak {
            return "You're improving every game! Keep going! 🔥"
        }

        // Beat your session high
        if sessionGamesPlayed >= 2 && lastGameScore < sessionHighScore {
            let diff = sessionHighScore - lastGameScore
            return "Just \(diff) more to beat your session best!"
        }

        // First game prompt
        if sessionGamesPlayed == 1 {
            return "Warm-up done! Your best game is next 💪"
        }

        // Milestone nudge
        if sessionGamesPlayed == 4 {
            return "Game 5 is the charm! One more? 🎲"
        }

        return nil
    }

    /// Context-appropriate play again label
    var playAgainLabel: String {
        if consecutiveLosses >= 3 {
            return "Try Again"
        }
        if isOnHotStreak {
            return "Keep the Streak! 🔥"
        }
        if sessionGamesPlayed >= 3 {
            return "One More Game"
        }
        return "Play Again"
    }

    // MARK: - Session Stats for Display

    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    var averageScore: Int {
        guard sessionGamesPlayed > 0 else { return 0 }
        return sessionTotalScore / sessionGamesPlayed
    }

    // MARK: - Mercy Mode (struggling player assistance)

    var shouldOfferMercy: Bool {
        consecutiveLosses >= 2
    }

    var mercyBonusPieces: Bool {
        // After 3+ losses, give easier starting pieces
        consecutiveLosses >= 3
    }

    // MARK: - Reset

    func resetSession() {
        sessionGamesPlayed = 0
        sessionHighScore = 0
        sessionTotalScore = 0
        sessionStartTime = Date()
        sessionBestCombo = 0
        sessionLinesCleared = 0
        consecutiveLosses = 0
        isOnHotStreak = false
        lastGameScore = 0
        scoresTrending = []
    }
}

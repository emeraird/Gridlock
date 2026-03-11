import StoreKit
import os.log

// MARK: - App Review Manager
// Smart prompting: only ask happy players at the right moment

final class AppReviewManager {
    static let shared = AppReviewManager()

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.gridlock.app", category: "AppReview")

    private enum Keys {
        static let lastPromptDate = "appReview_lastPromptDate"
        static let promptCount = "appReview_promptCount"
        static let hasRated = "appReview_hasRated"
    }

    private init() {}

    // MARK: - Configuration

    /// Minimum games before first prompt
    private let minGamesBeforePrompt = 8

    /// Minimum days between prompts
    private let minDaysBetweenPrompts = 30

    /// Max prompts ever (Apple limits to 3 per 365 days anyway)
    private let maxPrompts = 3

    /// Minimum score to consider a "good" session (player had fun)
    private let minScoreForPrompt = 200

    // MARK: - Prompt Logic

    /// Call after a game over with a decent score. Returns true if review was requested.
    @discardableResult
    func requestReviewIfAppropriate(score: Int, isNewHighScore: Bool) -> Bool {
        guard !defaults.bool(forKey: Keys.hasRated) else { return false }
        guard defaults.integer(forKey: Keys.promptCount) < maxPrompts else { return false }

        let gamesPlayed = UserProgressManager.shared.totalGamesPlayed
        guard gamesPlayed >= minGamesBeforePrompt else { return false }

        // Only prompt after a satisfying game
        guard score >= minScoreForPrompt || isNewHighScore else { return false }

        // Check cooldown
        if let lastPrompt = defaults.object(forKey: Keys.lastPromptDate) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            guard daysSince >= minDaysBetweenPrompts else { return false }
        }

        // Sweet spots: after new high score, or after milestone game numbers
        let sweetSpots = [8, 25, 50]  // Prompt at these game counts
        let isSweetSpot = sweetSpots.contains(gamesPlayed)
        let isHighScoreMoment = isNewHighScore && gamesPlayed >= minGamesBeforePrompt

        guard isSweetSpot || isHighScoreMoment else { return false }

        // All checks passed — request review
        requestReview()
        return true
    }

    private func requestReview() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            logger.warning("No window scene available for review prompt")
            return
        }

        defaults.set(Date(), forKey: Keys.lastPromptDate)
        defaults.set(defaults.integer(forKey: Keys.promptCount) + 1, forKey: Keys.promptCount)

        SKStoreReviewController.requestReview(in: windowScene)

        AnalyticsManager.shared.log(.appReviewPrompted, parameters: [
            "promptNumber": defaults.integer(forKey: Keys.promptCount)
        ])
        logger.info("App review requested (prompt #\(self.defaults.integer(forKey: Keys.promptCount)))")
    }

    /// Call if user explicitly goes to rate (from settings, etc.)
    func markAsRated() {
        defaults.set(true, forKey: Keys.hasRated)
    }
}

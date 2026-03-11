import Foundation
import os.log

// MARK: - Analytics Manager
// Lightweight event logging for key funnel metrics.
// Replace the log-based implementation with your analytics SDK (Firebase, Amplitude, etc.)

enum AnalyticsEvent: String {
    // Session
    case appLaunch
    case sessionStart
    case sessionEnd

    // Game funnel
    case gameStart
    case gameOver
    case gameOverContinue  // Used ad to continue
    case playAgain

    // Engagement
    case dailyRewardCollected
    case dailyRewardDoubled
    case milestoneReached
    case zoneEntered
    case newHighScore
    case streakMilestone

    // Monetization
    case interstitialShown
    case rewardedAdWatched
    case removeAdsUpsellShown
    case removeAdsUpsellTapped
    case iapPurchaseStarted
    case iapPurchaseCompleted
    case watchAdForPowerUp

    // Retention
    case notificationPermissionGranted
    case notificationPermissionDenied
    case tutorialCompleted
    case themeChanged
    case appReviewPrompted
}

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private let logger = Logger(subsystem: "com.gridlock.app", category: "Analytics")
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Event Logging

    func log(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        var message = "EVENT: \(event.rawValue)"
        if let params = parameters {
            let paramStr = params.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " [\(paramStr)]"
        }
        logger.info("\(message)")

        // TODO: Replace with real analytics SDK
        // Firebase.Analytics.logEvent(event.rawValue, parameters: parameters)
        // Amplitude.instance().logEvent(event.rawValue, withEventProperties: parameters)

        // Track cumulative counts for key events
        incrementCounter(for: event)
    }

    // MARK: - Funnel Metrics

    func logGameOver(score: Int, linesCleared: Int, bestCombo: Int, timeElapsed: TimeInterval, isNewHigh: Bool) {
        log(.gameOver, parameters: [
            "score": score,
            "lines": linesCleared,
            "combo": bestCombo,
            "time": Int(timeElapsed),
            "newHigh": isNewHigh
        ])
    }

    func logMilestone(name: String, score: Int, isFirstTime: Bool) {
        log(.milestoneReached, parameters: [
            "name": name,
            "score": score,
            "firstTime": isFirstTime
        ])
    }

    func logIAP(productID: String, success: Bool) {
        let event: AnalyticsEvent = success ? .iapPurchaseCompleted : .iapPurchaseStarted
        log(event, parameters: ["productID": productID])
    }

    // MARK: - Counter Tracking

    private func incrementCounter(for event: AnalyticsEvent) {
        let key = "analytics_count_\(event.rawValue)"
        let count = defaults.integer(forKey: key) + 1
        defaults.set(count, forKey: key)
    }

    func count(for event: AnalyticsEvent) -> Int {
        defaults.integer(forKey: "analytics_count_\(event.rawValue)")
    }

    // MARK: - Session Tracking

    func logSessionStart() {
        let sessionCount = defaults.integer(forKey: "analytics_sessionCount") + 1
        defaults.set(sessionCount, forKey: "analytics_sessionCount")
        log(.sessionStart, parameters: ["sessionNumber": sessionCount])
    }

    var totalSessions: Int {
        defaults.integer(forKey: "analytics_sessionCount")
    }
}

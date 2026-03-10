import Foundation
import os.log

// MARK: - Ad Manager (Stub — replace with Google AdMob SDK integration)

/// Ad placement types
enum AdPlacement: String {
    case continueAfterGameOver
    case freePowerUp
    case doubleDailyReward
    case interstitialAfterGame
}

final class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published var isRewardedAdReady: Bool = false
    @Published var isInterstitialReady: Bool = false

    private var interstitialCount = 0
    private var lastInterstitialTime: Date?
    private var rewardedAdsToday = 0
    private var rewardedPowerUpsToday = 0
    private var lastRewardedDate: Date?
    private var continueUsedThisGame = false
    private var sessionGameCount = 0

    private let logger = Logger(subsystem: "com.gridlock.app", category: "AdManager")

    private init() {
        resetDailyCountsIfNeeded()
    }

    // MARK: - Session Management

    func onSessionStart() {
        sessionGameCount = 0
        interstitialCount = 0
        lastInterstitialTime = nil
    }

    func onGameStart() {
        sessionGameCount += 1
        continueUsedThisGame = false
    }

    // MARK: - Ad Availability

    func canShowInterstitial() -> Bool {
        let progress = UserProgressManager.shared

        // Honeymoon period
        guard !progress.isInHoneymoonPeriod else { return false }

        // Remove ads subscription
        guard !progress.removeAdsActive else { return false }

        // First game of session
        if sessionGameCount <= 1 && !MonetizationConfig.showInterstitialOnFirstSessionGame {
            return false
        }

        // Session cap
        guard interstitialCount < MonetizationConfig.interstitialMaxPerSession else { return false }

        // Time interval
        if let lastTime = lastInterstitialTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            guard elapsed >= MonetizationConfig.interstitialMinInterval else { return false }
        }

        return isInterstitialReady
    }

    func canShowRewardedAd(placement: AdPlacement) -> Bool {
        let progress = UserProgressManager.shared

        // Honeymoon period for non-essential placements
        if progress.isInHoneymoonPeriod && placement != .continueAfterGameOver {
            return false
        }

        resetDailyCountsIfNeeded()

        switch placement {
        case .continueAfterGameOver:
            guard !continueUsedThisGame else { return false }
            return isRewardedAdReady

        case .freePowerUp:
            guard rewardedPowerUpsToday < MonetizationConfig.rewardedPowerUpMaxPerDay else { return false }
            // Remove ads subscribers get free power-ups instead
            if progress.removeAdsActive { return false }
            return isRewardedAdReady

        case .doubleDailyReward:
            return isRewardedAdReady

        case .interstitialAfterGame:
            return canShowInterstitial()
        }
    }

    // MARK: - Ad Display (Stubs)

    /// Show a rewarded video ad. Call the completion handler with success/failure.
    func showRewardedAd(placement: AdPlacement, from viewController: Any?, completion: @escaping (Bool) -> Void) {
        guard canShowRewardedAd(placement: placement) else {
            completion(false)
            return
        }

        logger.info("Showing rewarded ad for \(placement.rawValue)")

        // TODO: Integrate Google AdMob SDK
        // GADRewardedAd.load(withAdUnitID: MonetizationConfig.AdUnitID.rewardedVideo, ...)
        // For now, simulate success
        rewardedAdsToday += 1

        if placement == .continueAfterGameOver {
            continueUsedThisGame = true
        }
        if placement == .freePowerUp {
            rewardedPowerUpsToday += 1
        }

        completion(true)
    }

    /// Show an interstitial ad.
    func showInterstitial(from viewController: Any?, completion: @escaping () -> Void) {
        guard canShowInterstitial() else {
            completion()
            return
        }

        logger.info("Showing interstitial ad")

        // TODO: Integrate Google AdMob SDK
        interstitialCount += 1
        lastInterstitialTime = Date()

        completion()
    }

    // MARK: - Preloading

    func preloadRewardedAd() {
        // TODO: GADRewardedAd.load(...)
        logger.debug("Preloading rewarded ad")
        isRewardedAdReady = true
    }

    func preloadInterstitial() {
        // TODO: GADInterstitialAd.load(...)
        logger.debug("Preloading interstitial")
        isInterstitialReady = true
    }

    // MARK: - Daily Reset

    private func resetDailyCountsIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDate = lastRewardedDate, !Calendar.current.isDate(today, inSameDayAs: lastDate) {
            rewardedAdsToday = 0
            rewardedPowerUpsToday = 0
        }
        lastRewardedDate = today
    }
}

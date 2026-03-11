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
    private var upsellsShownThisSession = 0
    private var lastUpsellDate: Date?
    private var totalInterstitialsShownLifetime = 0

    private let logger = Logger(subsystem: "com.gridlock.app", category: "AdManager")

    private init() {
        resetDailyCountsIfNeeded()
        totalInterstitialsShownLifetime = UserDefaults.standard.integer(forKey: "totalInterstitialsLifetime")
        lastUpsellDate = UserDefaults.standard.object(forKey: "lastUpsellDate") as? Date
    }

    // MARK: - Session Management

    func onSessionStart() {
        sessionGameCount = 0
        interstitialCount = 0
        lastInterstitialTime = nil
        upsellsShownThisSession = 0
        preloadRewardedAd()
        preloadInterstitial()
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

        // Smart pacing: only show every N games
        if sessionGameCount % MonetizationConfig.interstitialEveryNGames != 0 {
            return false
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
            guard MonetizationConfig.doubleDailyRewardEnabled else { return false }
            return isRewardedAdReady

        case .interstitialAfterGame:
            return canShowInterstitial()
        }
    }

    // MARK: - Upsell Logic

    /// Whether to show "Remove Ads" soft upsell
    func shouldShowRemoveAdsUpsell() -> Bool {
        let progress = UserProgressManager.shared
        guard !progress.removeAdsActive else { return false }
        guard !progress.isInHoneymoonPeriod else { return false }
        guard upsellsShownThisSession < MonetizationConfig.removeAdsUpsellMaxPerSession else { return false }

        // Cooldown check
        if let lastDate = lastUpsellDate {
            guard Date().timeIntervalSince(lastDate) >= MonetizationConfig.removeAdsUpsellCooldown else { return false }
        }

        // Show after N interstitials
        guard totalInterstitialsShownLifetime >= MonetizationConfig.removeAdsUpsellAfterInterstitials else { return false }

        return true
    }

    func recordUpsellShown() {
        upsellsShownThisSession += 1
        lastUpsellDate = Date()
        UserDefaults.standard.set(lastUpsellDate, forKey: "lastUpsellDate")
        logger.info("Remove ads upsell shown (session count: \(self.upsellsShownThisSession))")
    }

    /// Whether to suggest theme purchases
    func shouldSuggestThemes() -> Bool {
        let progress = UserProgressManager.shared
        guard progress.gamesPlayedSinceInstall >= MonetizationConfig.themeUpsellAfterGames else { return false }
        // Don't suggest if user already owns themes
        guard progress.purchasedThemes.count <= 1 else { return false }
        return true
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

        // Track conversion
        trackConversion(placement: placement, success: true)

        completion(true)

        // Preload next ad
        preloadRewardedAd()
    }

    /// Show an interstitial ad.
    func showInterstitial(from viewController: Any?, completion: @escaping () -> Void) {
        guard canShowInterstitial() else {
            completion()
            return
        }

        logger.info("Showing interstitial ad (#\(self.interstitialCount + 1) this session)")

        // TODO: Integrate Google AdMob SDK
        interstitialCount += 1
        totalInterstitialsShownLifetime += 1
        UserDefaults.standard.set(totalInterstitialsShownLifetime, forKey: "totalInterstitialsLifetime")
        lastInterstitialTime = Date()

        // Preload next
        preloadInterstitial()

        completion()
    }

    // MARK: - Smart Interstitial (post-game)

    /// Call after every game over. Handles interstitial + optional upsell flow.
    func handlePostGameAd(from viewController: Any?, completion: @escaping (_ showedAd: Bool, _ shouldUpsell: Bool) -> Void) {
        if canShowInterstitial() {
            showInterstitial(from: viewController) { [weak self] in
                guard let self = self else { return }
                let shouldUpsell = self.shouldShowRemoveAdsUpsell()
                if shouldUpsell {
                    self.recordUpsellShown()
                }
                completion(true, shouldUpsell)
            }
        } else {
            completion(false, false)
        }
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

    // MARK: - Conversion Tracking

    private func trackConversion(placement: AdPlacement, success: Bool) {
        let key = "adConversion_\(placement.rawValue)"
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
        logger.info("Ad conversion: \(placement.rawValue) total=\(count + 1)")
    }

    // MARK: - Stats for Debug

    var debugStats: String {
        """
        Session games: \(sessionGameCount)
        Interstitials: \(interstitialCount)/\(MonetizationConfig.interstitialMaxPerSession)
        Rewarded today: \(rewardedAdsToday)/\(MonetizationConfig.rewardedAdMaxPerDay)
        Power-up ads: \(rewardedPowerUpsToday)/\(MonetizationConfig.rewardedPowerUpMaxPerDay)
        Lifetime interstitials: \(totalInterstitialsShownLifetime)
        """
    }
}

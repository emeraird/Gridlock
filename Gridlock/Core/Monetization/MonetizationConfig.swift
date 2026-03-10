import Foundation

struct MonetizationConfig {
    static let honeymoonGames = 5
    static let interstitialMinInterval: TimeInterval = 180  // 3 min between interstitials
    static let interstitialMaxPerSession = 4
    static let rewardedAdMaxPerDay = 5
    static let rewardedContinueMaxPerGame = 1
    static let showInterstitialOnFirstSessionGame = false
    static let notificationPermissionPromptAfterGame = 3
    static let rewardedPowerUpMaxPerDay = 3

    // IAP Product IDs
    enum ProductID {
        static let removeAdsMonthly = "gridlock.removeads.monthly"
        static let removeAdsYearly = "gridlock.removeads.yearly"
        static let themeNeon = "gridlock.theme.neon"
        static let themeOcean = "gridlock.theme.ocean"
        static let themeSpace = "gridlock.theme.space"
        static let powerPack = "gridlock.powerpack"

        static let allSubscriptions = [removeAdsMonthly, removeAdsYearly]
        static let allThemes = [themeNeon, themeOcean, themeSpace]
        static let all = allSubscriptions + allThemes + [powerPack]
    }

    // Ad Unit IDs (test IDs for development)
    enum AdUnitID {
        static let rewardedVideo = "ca-app-pub-3940256099942544/1712485313"  // Test ID
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"   // Test ID
    }
}

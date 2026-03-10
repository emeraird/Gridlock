import Foundation
import os.log

final class UserProgressManager: ObservableObject {
    static let shared = UserProgressManager()

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.gridlock.app", category: "UserProgress")

    // MARK: - Keys
    private enum Keys {
        static let highScore = "highScore"
        static let totalGamesPlayed = "totalGamesPlayed"
        static let totalLinesCleared = "totalLinesCleared"
        static let totalBlocksPlaced = "totalBlocksPlaced"
        static let longestCombo = "longestCombo"
        static let totalTimePlayed = "totalTimePlayed"
        static let tutorialCompleted = "tutorialCompleted"
        static let gamesPlayedSinceInstall = "gamesPlayedSinceInstall"
        static let hasRatedApp = "hasRatedApp"
        static let lastSessionDate = "lastSessionDate"
        static let removeAdsActive = "removeAdsActive"
        static let purchasedThemes = "purchasedThemes"
    }

    // MARK: - Properties

    @Published var highScore: Int {
        didSet { defaults.set(highScore, forKey: Keys.highScore) }
    }
    @Published var totalGamesPlayed: Int {
        didSet { defaults.set(totalGamesPlayed, forKey: Keys.totalGamesPlayed) }
    }
    @Published var totalLinesCleared: Int {
        didSet { defaults.set(totalLinesCleared, forKey: Keys.totalLinesCleared) }
    }
    @Published var totalBlocksPlaced: Int {
        didSet { defaults.set(totalBlocksPlaced, forKey: Keys.totalBlocksPlaced) }
    }
    @Published var longestCombo: Int {
        didSet { defaults.set(longestCombo, forKey: Keys.longestCombo) }
    }
    @Published var totalTimePlayed: TimeInterval {
        didSet { defaults.set(totalTimePlayed, forKey: Keys.totalTimePlayed) }
    }
    @Published var tutorialCompleted: Bool {
        didSet { defaults.set(tutorialCompleted, forKey: Keys.tutorialCompleted) }
    }
    @Published var removeAdsActive: Bool {
        didSet { defaults.set(removeAdsActive, forKey: Keys.removeAdsActive) }
    }

    var purchasedThemes: Set<String> {
        get {
            Set(defaults.stringArray(forKey: Keys.purchasedThemes) ?? [])
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.purchasedThemes)
        }
    }

    var gamesPlayedSinceInstall: Int {
        get { defaults.integer(forKey: Keys.gamesPlayedSinceInstall) }
        set { defaults.set(newValue, forKey: Keys.gamesPlayedSinceInstall) }
    }

    var isInHoneymoonPeriod: Bool {
        gamesPlayedSinceInstall < MonetizationConfig.honeymoonGames
    }

    // MARK: - Init

    private init() {
        highScore = defaults.integer(forKey: Keys.highScore)
        totalGamesPlayed = defaults.integer(forKey: Keys.totalGamesPlayed)
        totalLinesCleared = defaults.integer(forKey: Keys.totalLinesCleared)
        totalBlocksPlaced = defaults.integer(forKey: Keys.totalBlocksPlaced)
        longestCombo = defaults.integer(forKey: Keys.longestCombo)
        totalTimePlayed = defaults.double(forKey: Keys.totalTimePlayed)
        tutorialCompleted = defaults.bool(forKey: Keys.tutorialCompleted)
        removeAdsActive = defaults.bool(forKey: Keys.removeAdsActive)
    }

    // MARK: - Recording

    func recordGameEnd(score: Int, linesCleared: Int, blocksPlaced: Int, maxCombo: Int, duration: TimeInterval) {
        totalGamesPlayed += 1
        gamesPlayedSinceInstall += 1
        totalLinesCleared += linesCleared
        totalBlocksPlaced += blocksPlaced
        totalTimePlayed += duration

        if score > highScore {
            highScore = score
        }
        if maxCombo > longestCombo {
            longestCombo = maxCombo
        }

        defaults.set(Date(), forKey: Keys.lastSessionDate)

        logger.info("Game recorded: score=\(score), lines=\(linesCleared), blocks=\(blocksPlaced)")
    }

    func hasTheme(_ themeId: String) -> Bool {
        purchasedThemes.contains(themeId)
    }

    func unlockTheme(_ themeId: String) {
        var themes = purchasedThemes
        themes.insert(themeId)
        purchasedThemes = themes
    }
}

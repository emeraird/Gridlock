import Foundation
import Combine
import os.log

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: GameTheme
    @Published var availableThemes: [GameTheme] = []

    private let defaults = UserDefaults.standard
    private let themeKey = "selectedThemeID"
    private let logger = Logger(subsystem: "com.gridlock.app", category: "ThemeManager")

    private init() {
        let allThemes: [GameTheme] = [
            ClassicTheme(),
            NeonTheme(),
            OceanTheme(),
            SpaceTheme()
        ]
        availableThemes = allThemes

        let savedID = defaults.string(forKey: themeKey) ?? "classic"
        currentTheme = allThemes.first { $0.id == savedID } ?? ClassicTheme()
    }

    func selectTheme(_ theme: GameTheme) {
        // Verify purchase for premium themes
        if theme.isPremium {
            guard isThemeUnlocked(theme) else {
                logger.warning("Attempted to select locked theme: \(theme.id)")
                return
            }
        }

        currentTheme = theme
        defaults.set(theme.id, forKey: themeKey)
        logger.info("Theme changed to: \(theme.name)")
    }

    func isThemeUnlocked(_ theme: GameTheme) -> Bool {
        if !theme.isPremium { return true }
        if let productID = theme.productID {
            return IAPManager.shared.isThemePurchased(productID)
                || UserProgressManager.shared.hasTheme(theme.id)
        }
        return false
    }

    func theme(for id: String) -> GameTheme? {
        availableThemes.first { $0.id == id }
    }
}

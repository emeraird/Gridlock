import UIKit

// MARK: - Game Theme Protocol

protocol GameTheme {
    var id: String { get }
    var name: String { get }
    var isPremium: Bool { get }
    var productID: String? { get }

    // Grid
    var gridBackgroundColor: UIColor { get }
    var gridLineColor: UIColor { get }
    var cellEmptyColor: UIColor { get }

    // Blocks
    var blockColors: [UIColor] { get }  // 5 distinct block colors matching BlockColor cases
    var blockTexture: String? { get }

    // Effects
    var particleColor: UIColor { get }
    var clearLineParticleColors: [UIColor] { get }

    // Background
    var backgroundColor: UIColor { get }
    var backgroundGradientColors: [UIColor]? { get }

    // Text
    var scoreTextColor: UIColor { get }
    var comboTextColors: [UIColor] { get }  // Escalating intensity

    // UI
    var uiAccentColor: UIColor { get }
    var buttonColor: UIColor { get }
    var buttonTextColor: UIColor { get }

    // Audio
    var backgroundMusicFile: String? { get }
}

// MARK: - Default Implementations

extension GameTheme {
    var blockTexture: String? { nil }
    var backgroundGradientColors: [UIColor]? { nil }
    var backgroundMusicFile: String? { nil }

    func blockColor(for type: BlockColor) -> UIColor {
        blockColors[type.index % blockColors.count]
    }

    func comboColor(for level: Int) -> UIColor {
        let index = min(level - 1, comboTextColors.count - 1)
        return comboTextColors[max(0, index)]
    }
}

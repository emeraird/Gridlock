import UIKit

struct OceanTheme: GameTheme {
    let id = "ocean"
    let name = "Deep Ocean"
    let isPremium = true
    let productID: String? = MonetizationConfig.ProductID.themeOcean

    let gridBackgroundColor = UIColor(hex: "0A2342")
    let gridLineColor = UIColor(hex: "1B4965").withAlphaComponent(0.6)
    let cellEmptyColor = UIColor(hex: "0D2B4E")

    let blockColors: [UIColor] = [
        UIColor(hex: "FF6B6B"),  // Coral
        UIColor(hex: "5CE1E6"),  // Turquoise
        UIColor(hex: "7ED957"),  // Seaweed green
        UIColor(hex: "FFD93D"),  // Sand gold
        UIColor(hex: "C77DFF"),  // Sea urchin purple
    ]

    let particleColor = UIColor(hex: "5CE1E6")
    let clearLineParticleColors: [UIColor] = [
        UIColor(hex: "5CE1E6"),
        UIColor(hex: "62C9FF"),
        UIColor.white.withAlphaComponent(0.8)
    ]

    let backgroundColor = UIColor(hex: "051B32")
    let backgroundGradientColors: [UIColor]? = [
        UIColor(hex: "051B32"),
        UIColor(hex: "0A2342"),
        UIColor(hex: "0E3460")
    ]

    let scoreTextColor = UIColor(hex: "5CE1E6")
    let comboTextColors: [UIColor] = [
        UIColor(hex: "5CE1E6"),
        UIColor(hex: "62C9FF"),
        UIColor(hex: "FFD93D"),
        UIColor(hex: "FF6B6B"),
        UIColor(hex: "C77DFF"),
    ]

    let uiAccentColor = UIColor(hex: "5CE1E6")
    let buttonColor = UIColor(hex: "1B4965")
    let buttonTextColor = UIColor(hex: "5CE1E6")
}

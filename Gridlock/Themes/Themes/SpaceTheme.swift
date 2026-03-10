import UIKit

struct SpaceTheme: GameTheme {
    let id = "space"
    let name = "Cosmic"
    let isPremium = true
    let productID: String? = MonetizationConfig.ProductID.themeSpace

    let gridBackgroundColor = UIColor(hex: "0B0B1E")
    let gridLineColor = UIColor(hex: "1E1E3F").withAlphaComponent(0.5)
    let cellEmptyColor = UIColor(hex: "0E0E28")

    let blockColors: [UIColor] = [
        UIColor(hex: "FF4D6D"),  // Nebula red
        UIColor(hex: "48BFE3"),  // Star blue
        UIColor(hex: "64DFDF"),  // Aurora green
        UIColor(hex: "FFE45E"),  // Star gold
        UIColor(hex: "9B5DE5"),  // Galaxy purple
    ]

    let particleColor = UIColor(hex: "FFE45E")
    let clearLineParticleColors: [UIColor] = [
        UIColor(hex: "FFE45E"),
        UIColor(hex: "48BFE3"),
        UIColor(hex: "9B5DE5"),
        UIColor.white
    ]

    let backgroundColor = UIColor(hex: "050514")
    let backgroundGradientColors: [UIColor]? = [
        UIColor(hex: "050514"),
        UIColor(hex: "0B0B1E"),
        UIColor(hex: "1A0A2E")
    ]

    let scoreTextColor = UIColor(hex: "FFE45E")
    let comboTextColors: [UIColor] = [
        UIColor(hex: "48BFE3"),
        UIColor(hex: "64DFDF"),
        UIColor(hex: "FFE45E"),
        UIColor(hex: "FF4D6D"),
        UIColor(hex: "9B5DE5"),
    ]

    let uiAccentColor = UIColor(hex: "9B5DE5")
    let buttonColor = UIColor(hex: "9B5DE5")
    let buttonTextColor = UIColor.white
}

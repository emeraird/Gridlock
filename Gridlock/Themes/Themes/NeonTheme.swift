import UIKit

struct NeonTheme: GameTheme {
    let id = "neon"
    let name = "Neon Glow"
    let isPremium = true
    let productID: String? = MonetizationConfig.ProductID.themeNeon

    let gridBackgroundColor = UIColor(hex: "0A0A1A")
    let gridLineColor = UIColor(hex: "1A1A3A").withAlphaComponent(0.8)
    let cellEmptyColor = UIColor(hex: "0D0D2B")

    let blockColors: [UIColor] = [
        UIColor(hex: "FF0080"),  // Hot pink
        UIColor(hex: "00FFFF"),  // Cyan
        UIColor(hex: "39FF14"),  // Lime green
        UIColor(hex: "0080FF"),  // Electric blue
        UIColor(hex: "FF6600"),  // Neon orange
    ]

    let particleColor = UIColor(hex: "00FFFF")
    let clearLineParticleColors: [UIColor] = [
        UIColor(hex: "FF0080"),
        UIColor(hex: "00FFFF"),
        UIColor(hex: "39FF14")
    ]

    let backgroundColor = UIColor(hex: "050510")
    let scoreTextColor = UIColor(hex: "00FFFF")
    let comboTextColors: [UIColor] = [
        UIColor(hex: "00FFFF"),
        UIColor(hex: "39FF14"),
        UIColor(hex: "FF0080"),
        UIColor(hex: "FFE500"),
        UIColor(hex: "FF00FF"),
    ]

    let uiAccentColor = UIColor(hex: "FF0080")
    let buttonColor = UIColor(hex: "FF0080")
    let buttonTextColor = UIColor.white
}

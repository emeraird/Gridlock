import UIKit

struct ClassicTheme: GameTheme {
    let id = "classic"
    let name = "Classic"
    let isPremium = false
    let productID: String? = nil

    let gridBackgroundColor = UIColor(hex: "1A1A2E")
    let gridLineColor = UIColor(hex: "2A2A4A")
    let cellEmptyColor = UIColor(hex: "16213E")

    let blockColors: [UIColor] = [
        UIColor(hex: "FF6B6B"),  // Red
        UIColor(hex: "4ECDC4"),  // Blue/Teal
        UIColor(hex: "95E77E"),  // Green
        UIColor(hex: "FFE66D"),  // Yellow
        UIColor(hex: "C77DFF"),  // Purple
    ]

    let particleColor = UIColor.white
    let clearLineParticleColors: [UIColor] = [
        UIColor.white,
        UIColor(hex: "FFE66D"),
        UIColor(hex: "4ECDC4")
    ]

    let backgroundColor = UIColor(hex: "0F0F23")
    let scoreTextColor = UIColor.white
    let comboTextColors: [UIColor] = [
        UIColor.white,
        UIColor(hex: "FFE66D"),
        UIColor(hex: "FFA500"),
        UIColor(hex: "FF4500"),
        UIColor(hex: "FF00FF"),
    ]

    let uiAccentColor = UIColor(hex: "E94560")
    let buttonColor = UIColor(hex: "E94560")
    let buttonTextColor = UIColor.white
}

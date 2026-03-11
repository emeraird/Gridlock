import UIKit

// MARK: - Sydney Theme
// A free, super cute Japanese-inspired kawaii cat theme.
// Soft sakura pinks, matcha greens, wisteria purples, and warm yuzu golds
// over a cozy twilight plum background — like a Tokyo night garden.

struct SydneyTheme: GameTheme {
    let id = "sydney"
    let name = "Sydney"
    let isPremium = false
    let productID: String? = nil

    // MARK: - Grid
    // Warm twilight plum tones — cozy and inviting

    let gridBackgroundColor = UIColor(hex: "241636")      // Warm dark violet
    let gridLineColor = UIColor(hex: "3A2258")             // Soft mauve grid lines
    let cellEmptyColor = UIColor(hex: "1F1430")            // Deep plum empty cells

    // MARK: - Block Colors
    // Five kawaii pastels inspired by Japanese aesthetics:
    //   Sakura pink, Matcha cream, Yuzu gold, Wisteria mist, Sora sky blue

    let blockColors: [UIColor] = [
        UIColor(hex: "F8A4B8"),  // Sakura Pink — cherry blossom petals
        UIColor(hex: "A8D8B9"),  // Matcha Cream — gentle green tea
        UIColor(hex: "FFD88A"),  // Yuzu Gold — warm citrus glow
        UIColor(hex: "C8A8E9"),  // Wisteria Mist — delicate fuji purple
        UIColor(hex: "89CFF0"),  // Sora Blue — clear spring sky
    ]

    // MARK: - Particle Effects
    // Sakura petal colors — like cherry blossoms drifting

    let particleColor = UIColor(hex: "FFE4E1")  // Misty rose
    let clearLineParticleColors: [UIColor] = [
        UIColor(hex: "F8A4B8"),  // Sakura pink
        UIColor(hex: "FFE4E1"),  // Misty rose
        UIColor(hex: "FFDAF0"),  // Light blush
        UIColor.white.withAlphaComponent(0.9),
    ]

    // MARK: - Background
    // Deep twilight garden gradient

    let backgroundColor = UIColor(hex: "1C1225")  // Twilight plum
    let backgroundGradientColors: [UIColor]? = [
        UIColor(hex: "1C1225"),  // Deep twilight
        UIColor(hex: "241636"),  // Warm violet
        UIColor(hex: "2D1B45"),  // Rich plum
    ]

    // MARK: - Text
    // Warm whites and soft pastels for readability

    let scoreTextColor = UIColor(hex: "FFE4E1")  // Misty rose — warm white

    // Combo colors escalate from cute to fierce
    let comboTextColors: [UIColor] = [
        UIColor(hex: "F8A4B8"),  // Sakura pink — Nice!
        UIColor(hex: "FFB86C"),  // Warm peach — Great!
        UIColor(hex: "FF7EB3"),  // Rose coral — Amazing!
        UIColor(hex: "FF4081"),  // Hot pink — INCREDIBLE!
        UIColor(hex: "E040FB"),  // Vivid magenta — UNBELIEVABLE!
    ]

    // MARK: - UI Elements
    // Soft sakura pink accent — cute button styling

    let uiAccentColor = UIColor(hex: "F48FB1")    // Medium sakura pink
    let buttonColor = UIColor(hex: "F48FB1")       // Matching pink buttons
    let buttonTextColor = UIColor.white
}

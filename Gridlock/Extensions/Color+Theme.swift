import UIKit
import SwiftUI

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    var lighter: UIColor {
        adjustBrightness(by: 0.2)
    }

    var darker: UIColor {
        adjustBrightness(by: -0.2)
    }

    func adjustBrightness(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, min(1, b + amount)), alpha: a)
    }

    func withSaturation(_ saturation: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: saturation, brightness: b, alpha: a)
    }

    var swiftUIColor: Color {
        Color(uiColor: self)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    // Common game colors
    static let gridBackground = Color(hex: "1A1A2E")
    static let gridLine = Color(hex: "2A2A4A")
    static let cellEmpty = Color(hex: "16213E")
    static let scoreText = Color.white
    static let accentGame = Color(hex: "E94560")

    // Block colors
    static let blockRed = Color(hex: "FF6B6B")
    static let blockBlue = Color(hex: "4ECDC4")
    static let blockGreen = Color(hex: "95E77E")
    static let blockYellow = Color(hex: "FFE66D")
    static let blockPurple = Color(hex: "C77DFF")
}

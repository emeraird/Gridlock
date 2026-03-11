import UIKit
import os.log

// MARK: - Share Card Generator
// Creates shareable image cards for game results

final class ShareCardGenerator {
    static let shared = ShareCardGenerator()
    private let logger = Logger(subsystem: "com.gridlock.app", category: "ShareCard")

    private init() {}

    struct GameResult {
        let score: Int
        let linesCleared: Int
        let bestCombo: Int
        let timeElapsed: TimeInterval
        let isNewHighScore: Bool
        let rank: Int // 1-3 in ghost standings
    }

    // MARK: - Generate Share Card

    func generateShareCard(result: GameResult) -> UIImage {
        let cardSize = CGSize(width: 600, height: 400)

        let renderer = UIGraphicsImageRenderer(size: cardSize)
        return renderer.image { context in
            let ctx = context.cgContext

            // Background gradient
            let colors = [
                UIColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 1.0).cgColor,
                UIColor(red: 0.15, green: 0.10, blue: 0.25, alpha: 1.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: colors as CFArray,
                                       locations: [0, 1])!
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: cardSize.width, y: cardSize.height),
                                   options: [])

            // Card border
            let borderRect = CGRect(x: 2, y: 2, width: cardSize.width - 4, height: cardSize.height - 4)
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 20)
            UIColor.orange.withAlphaComponent(0.4).setStroke()
            borderPath.lineWidth = 3
            borderPath.stroke()

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
            let titleText = "GRIDLOCK" as NSString
            let titleSize = titleText.size(withAttributes: titleAttrs)
            titleText.draw(at: CGPoint(x: (cardSize.width - titleSize.width) / 2, y: 25), withAttributes: titleAttrs)

            // Score (big, centered)
            let scoreAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .heavy),
                .foregroundColor: UIColor.orange
            ]
            let scoreText = "\(result.score)" as NSString
            let scoreSize = scoreText.size(withAttributes: scoreAttrs)
            scoreText.draw(at: CGPoint(x: (cardSize.width - scoreSize.width) / 2, y: 65), withAttributes: scoreAttrs)

            // New high score badge
            if result.isNewHighScore {
                let badgeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .heavy),
                    .foregroundColor: UIColor.yellow
                ]
                let badgeText = "⭐ NEW HIGH SCORE ⭐" as NSString
                let badgeSize = badgeText.size(withAttributes: badgeAttrs)
                badgeText.draw(at: CGPoint(x: (cardSize.width - badgeSize.width) / 2, y: 150), withAttributes: badgeAttrs)
            }

            // Stats row
            let statsY: CGFloat = result.isNewHighScore ? 190 : 170
            let stats: [(String, String)] = [
                ("Lines", "\(result.linesCleared)"),
                ("Best Combo", "\(result.bestCombo)x"),
                ("Time", formatTime(result.timeElapsed))
            ]

            let statWidth = cardSize.width / CGFloat(stats.count)
            for (i, stat) in stats.enumerated() {
                let x = statWidth * CGFloat(i)

                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let valueText = stat.1 as NSString
                let valueSize = valueText.size(withAttributes: valueAttrs)
                valueText.draw(at: CGPoint(x: x + (statWidth - valueSize.width) / 2, y: statsY), withAttributes: valueAttrs)

                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.5)
                ]
                let labelText = stat.0 as NSString
                let labelSize = labelText.size(withAttributes: labelAttrs)
                labelText.draw(at: CGPoint(x: x + (statWidth - labelSize.width) / 2, y: statsY + 35), withAttributes: labelAttrs)
            }

            // Separator
            let sepY = statsY + 65
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: 40, y: sepY))
            ctx.addLine(to: CGPoint(x: cardSize.width - 40, y: sepY))
            ctx.strokePath()

            // Rank medal
            let rankY = sepY + 20
            let rankEmoji: String
            switch result.rank {
            case 1: rankEmoji = "🥇"
            case 2: rankEmoji = "🥈"
            case 3: rankEmoji = "🥉"
            default: rankEmoji = "🎮"
            }

            let rankAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let rankText = "\(rankEmoji) Finished #\(result.rank)" as NSString
            let rankSize = rankText.size(withAttributes: rankAttrs)
            rankText.draw(at: CGPoint(x: (cardSize.width - rankSize.width) / 2, y: rankY), withAttributes: rankAttrs)

            // Call to action
            let ctaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.4)
            ]
            let ctaText = "Can you beat my score? 🔥" as NSString
            let ctaSize = ctaText.size(withAttributes: ctaAttrs)
            ctaText.draw(at: CGPoint(x: (cardSize.width - ctaSize.width) / 2, y: cardSize.height - 40), withAttributes: ctaAttrs)
        }
    }

    // MARK: - Share

    func shareGameResult(_ result: GameResult, from viewController: UIViewController?) {
        let image = generateShareCard(result: result)
        let text = "I scored \(result.score) in Gridlock! 🧩🔥 Can you beat me?"

        let activityVC = UIActivityViewController(
            activityItems: [text, image],
            applicationActivities: nil
        )

        if let vc = viewController {
            vc.present(activityVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        logger.info("Share card generated for score \(result.score)")
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

import SpriteKit
import UIKit

final class TextureGenerator {
    static let shared = TextureGenerator()

    private var cache: [String: SKTexture] = [:]

    private init() {}

    // MARK: - Block Textures

    /// Generate a colored block with rounded corners, subtle gradient (3D bevel), and inner highlight
    func blockTexture(color: UIColor, size: CGSize, cornerRadius: CGFloat = 4) -> SKTexture {
        let key = "block_\(color.hash)_\(size.width)x\(size.height)"
        if let cached = cache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

            // Base color fill
            color.setFill()
            path.fill()

            // Top highlight (lighter strip at top for 3D bevel)
            let highlightRect = CGRect(x: rect.minX + 2, y: rect.minY + 1, width: rect.width - 4, height: rect.height * 0.35)
            let highlightPath = UIBezierPath(roundedRect: highlightRect, cornerRadius: max(0, cornerRadius - 1))
            color.lighter.withAlphaComponent(0.4).setFill()
            highlightPath.fill()

            // Bottom shadow (darker strip at bottom)
            let shadowRect = CGRect(x: rect.minX + 2, y: rect.maxY - rect.height * 0.25, width: rect.width - 4, height: rect.height * 0.25 - 1)
            let shadowPath = UIBezierPath(roundedRect: shadowRect, cornerRadius: max(0, cornerRadius - 1))
            color.darker.withAlphaComponent(0.3).setFill()
            shadowPath.fill()

            // Subtle border
            color.darker.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }

        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: - Grid Cell Textures

    /// Empty grid cell with subtle background
    func emptyCellTexture(color: UIColor, size: CGSize, cornerRadius: CGFloat = 2) -> SKTexture {
        let key = "empty_\(color.hash)_\(size.width)x\(size.height)"
        if let cached = cache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

            color.setFill()
            path.fill()

            // Very subtle inner border
            color.lighter.withAlphaComponent(0.1).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }

        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: - Ghost Preview Textures

    /// Semi-transparent preview for valid/invalid placement
    func ghostTexture(color: UIColor, size: CGSize, valid: Bool, cornerRadius: CGFloat = 4) -> SKTexture {
        let tint = valid ? UIColor.green.withAlphaComponent(0.3) : UIColor.red.withAlphaComponent(0.3)
        let key = "ghost_\(valid)_\(size.width)x\(size.height)"
        if let cached = cache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            tint.setFill()
            path.fill()

            let borderColor = valid ? UIColor.green.withAlphaComponent(0.5) : UIColor.red.withAlphaComponent(0.5)
            borderColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: - Grid Background

    /// Full grid background texture with cell outlines
    func gridBackgroundTexture(gridSize: Int, cellSize: CGFloat, backgroundColor: UIColor, lineColor: UIColor, cellColor: UIColor) -> SKTexture {
        let totalSize = CGFloat(gridSize) * cellSize
        let size = CGSize(width: totalSize, height: totalSize)
        let key = "gridbg_\(gridSize)_\(cellSize)"
        if let cached = cache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Background
            backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Draw cells
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let cellRect = CGRect(
                        x: CGFloat(col) * cellSize + 1,
                        y: CGFloat(row) * cellSize + 1,
                        width: cellSize - 2,
                        height: cellSize - 2
                    )
                    let cellPath = UIBezierPath(roundedRect: cellRect, cornerRadius: 2)
                    cellColor.setFill()
                    cellPath.fill()
                }
            }

            // Draw grid lines
            lineColor.setStroke()
            for i in 0...gridSize {
                let pos = CGFloat(i) * cellSize
                let hLine = UIBezierPath()
                hLine.move(to: CGPoint(x: 0, y: pos))
                hLine.addLine(to: CGPoint(x: totalSize, y: pos))
                hLine.lineWidth = 0.5
                hLine.stroke()

                let vLine = UIBezierPath()
                vLine.move(to: CGPoint(x: pos, y: 0))
                vLine.addLine(to: CGPoint(x: pos, y: totalSize))
                vLine.lineWidth = 0.5
                vLine.stroke()
            }
        }

        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: - Power-up Icons

    func powerUpIconTexture(type: String, size: CGSize, color: UIColor) -> SKTexture {
        let key = "powerup_\(type)_\(size.width)"
        if let cached = cache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            color.withAlphaComponent(0.3).setFill()
            circlePath.fill()
            color.setStroke()
            circlePath.lineWidth = 2
            circlePath.stroke()
        }

        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: - Piece Tray Slot

    func traySlotTexture(size: CGSize, color: UIColor) -> SKTexture {
        let key = "trayslot_\(size.width)x\(size.height)"
        if let cached = cache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            color.withAlphaComponent(0.15).setFill()
            path.fill()
            color.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: - Cache Management

    func clearCache() {
        cache.removeAll()
    }

    func preloadThemeTextures(theme: GameTheme, cellSize: CGFloat) {
        let blockSize = CGSize(width: cellSize - 2, height: cellSize - 2)
        for color in theme.blockColors {
            _ = blockTexture(color: color, size: blockSize)
        }
        _ = emptyCellTexture(color: theme.cellEmptyColor, size: CGSize(width: cellSize, height: cellSize))
        _ = ghostTexture(color: .green, size: blockSize, valid: true)
        _ = ghostTexture(color: .red, size: blockSize, valid: false)
        _ = gridBackgroundTexture(
            gridSize: 8, cellSize: cellSize,
            backgroundColor: theme.gridBackgroundColor,
            lineColor: theme.gridLineColor,
            cellColor: theme.cellEmptyColor
        )
    }
}

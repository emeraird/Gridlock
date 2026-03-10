import Foundation
import os.log

final class PieceGenerator {
    private let logger = Logger(subsystem: "com.gridlock.app", category: "PieceGenerator")

    // Adaptive difficulty tracking
    private var recentClears: [Bool] = []  // true = cleared lines after placement
    private let recentWindow = 20

    // Difficulty ranges from 0 (easy) to 1 (hard)
    private(set) var currentDifficulty: Double = 0.3

    // Tutorial mode gives easier pieces
    var isTutorialMode: Bool = false

    func generatePieces(count: Int = 3, grid: GridModel) -> [BlockPiece] {
        var pieces: [BlockPiece] = []

        for i in 0..<count {
            let piece: BlockPiece
            if i == 0 && !isTutorialMode {
                // First piece: 70% chance it fits on the board
                piece = generateWithPlaceabilityBias(grid: grid, fitProbability: 0.7)
            } else if isTutorialMode {
                // Tutorial: always placeable, easy shapes
                piece = generateTutorialPiece(grid: grid)
            } else {
                piece = generateAdaptivePiece(grid: grid)
            }
            pieces.append(piece)
        }

        // Ensure at least one piece is placeable when possible
        let anyPlaceable = pieces.contains { grid.canPlacePieceAnywhere($0) }
        if !anyPlaceable {
            // Replace the first piece with one guaranteed to fit
            if let replacement = findPlaceablePiece(grid: grid) {
                pieces[0] = replacement
            }
        }

        logger.debug("Generated \(pieces.count) pieces, difficulty=\(String(format: "%.2f", self.currentDifficulty))")
        return pieces
    }

    // MARK: - Adaptive Difficulty

    func recordPlacement(didClearLines: Bool) {
        recentClears.append(didClearLines)
        if recentClears.count > recentWindow {
            recentClears.removeFirst()
        }
        updateDifficulty()
    }

    private func updateDifficulty() {
        guard recentClears.count >= 5 else { return }
        let clearRate = Double(recentClears.filter { $0 }.count) / Double(recentClears.count)

        // If player clears frequently, increase difficulty; if struggling, decrease
        if clearRate > 0.5 {
            currentDifficulty = min(1.0, currentDifficulty + 0.05)
        } else if clearRate < 0.2 {
            currentDifficulty = max(0.0, currentDifficulty - 0.05)
        }
    }

    // MARK: - Generation Strategies

    private func generateWithPlaceabilityBias(grid: GridModel, fitProbability: Double) -> BlockPiece {
        if Double.random(in: 0...1) < fitProbability {
            if let piece = findPlaceablePiece(grid: grid) {
                return piece
            }
        }
        return randomPiece()
    }

    private func generateAdaptivePiece(grid: GridModel) -> BlockPiece {
        let shapes = weightedShapes()
        let shape = shapes.randomElement() ?? .triomino
        let color = BlockColor.allCases.randomElement() ?? .red
        return BlockPiece(shape: shape, color: color)
    }

    private func generateTutorialPiece(grid: GridModel) -> BlockPiece {
        let easyShapes: [PieceShape] = [.single, .domino, .triomino, .square2x2, .corner2x2]
        let shape = easyShapes.randomElement() ?? .triomino
        let color = BlockColor.allCases.randomElement() ?? .blue
        let piece = BlockPiece(shape: shape, color: color)

        // Make sure it fits
        if grid.canPlacePieceAnywhere(piece) {
            return piece
        }

        // Fallback: try all easy shapes
        for s in easyShapes {
            let p = BlockPiece(shape: s, color: color)
            if grid.canPlacePieceAnywhere(p) {
                return p
            }
        }
        return piece
    }

    private func findPlaceablePiece(grid: GridModel) -> BlockPiece? {
        let shuffledShapes = PieceShape.allCases.shuffled()
        for shape in shuffledShapes {
            let color = BlockColor.allCases.randomElement() ?? .red
            let piece = BlockPiece(shape: shape, color: color)
            if grid.canPlacePieceAnywhere(piece) {
                return piece
            }
        }
        return nil
    }

    private func weightedShapes() -> [PieceShape] {
        var pool: [PieceShape] = []
        for shape in PieceShape.allCases {
            let weight: Int
            if currentDifficulty > 0.6 {
                // Hard: favor big/awkward pieces
                weight = shape.difficultyWeight > 0.5 ? 3 : 1
            } else if currentDifficulty < 0.3 {
                // Easy: favor small/simple pieces
                weight = shape.difficultyWeight < 0.5 ? 3 : 1
            } else {
                // Balanced
                weight = 2
            }
            pool.append(contentsOf: Array(repeating: shape, count: weight))
        }
        return pool
    }

    private func randomPiece() -> BlockPiece {
        let shape = PieceShape.allCases.randomElement() ?? .triomino
        let color = BlockColor.allCases.randomElement() ?? .red
        return BlockPiece(shape: shape, color: color)
    }

    // MARK: - Daily Challenge (Seeded)

    func generateSeededPieces(seed: UInt64, count: Int = 3) -> [BlockPiece] {
        var rng = SeededRandomNumberGenerator(seed: seed)
        return (0..<count).map { _ in
            let shapeIndex = Int.random(in: 0..<PieceShape.allCases.count, using: &rng)
            let colorIndex = Int.random(in: 0..<BlockColor.allCases.count, using: &rng)
            return BlockPiece(
                shape: PieceShape.allCases[shapeIndex],
                color: BlockColor.allCases[colorIndex]
            )
        }
    }
}

// MARK: - Seeded RNG for Daily Challenge

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

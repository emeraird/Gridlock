import Foundation
import os.log

// MARK: - Placement Record (Sliding Window Entry)

struct PlacementRecord {
    let didClearLine: Bool
    let cellsCleared: Int
    let wasNearMiss: Bool
    let boardFillPercentage: Double
}

// MARK: - Piece Generator with Pressure-Based Adaptive Difficulty

final class PieceGenerator {
    private let logger = Logger(subsystem: "com.gridlock.app", category: "PieceGenerator")

    // Sliding window of recent placements
    private var recentPlacements: [PlacementRecord] = []
    private let windowSize = 12

    // Computed pressure score (0 = struggling, 1 = dominating)
    private(set) var pressureScore: Double = 0.3

    // Track near-death events for engineering
    private var consecutiveHighFillSets = 0

    // Legacy compatibility
    var currentDifficulty: Double { pressureScore }

    // Tutorial mode gives easier pieces
    var isTutorialMode: Bool = false

    // MARK: - Piece Generation

    func generatePieces(count: Int = 3, grid: GridModel) -> [BlockPiece] {
        if isTutorialMode {
            return generateTutorialPieces(count: count, grid: grid)
        }

        let fillPct = BoardAnalyzer.fillPercentage(grid: grid)
        var pieces: [BlockPiece] = []

        if pressureScore < 0.25 {
            // STRUGGLING: Be generous
            pieces = generateStrugglingPieces(count: count, grid: grid)
        } else if pressureScore > 0.80 {
            // CRUSHING IT: Create puzzle-within-puzzle
            pieces = generateCrushingPieces(count: count, grid: grid)
        } else if pressureScore > 0.60 {
            // DOMINATING: Push back with harder shapes
            pieces = generateDominatingPieces(count: count, grid: grid)
        } else {
            // SWEET SPOT (0.25 - 0.60): Standard random, flow state zone
            pieces = generateFlowPieces(count: count, grid: grid)
        }

        // Near-death experience engineering
        if fillPct > 0.75 {
            consecutiveHighFillSets += 1
            // Every ~3rd high-fill set, guarantee a line-clearing opportunity
            if consecutiveHighFillSets >= 2 {
                pieces = engineerNearDeathRescue(pieces: pieces, grid: grid)
                consecutiveHighFillSets = 0
            }
        } else {
            consecutiveHighFillSets = 0
        }

        // Safety: ensure at least one piece is placeable
        let anyPlaceable = pieces.contains { grid.canPlacePieceAnywhere($0) }
        if !anyPlaceable {
            if let replacement = findPlaceablePiece(grid: grid) {
                pieces[0] = replacement
            }
        }

        logger.debug("Generated \(pieces.count) pieces, pressure=\(String(format: "%.2f", self.pressureScore)), fill=\(String(format: "%.0f%%", fillPct * 100))")
        return pieces
    }

    // MARK: - Record Placement & Update Pressure

    func recordPlacement(didClearLines: Bool, cellsCleared: Int = 0, grid: GridModel) {
        let record = PlacementRecord(
            didClearLine: didClearLines,
            cellsCleared: cellsCleared,
            wasNearMiss: false, // Computed retroactively if needed
            boardFillPercentage: BoardAnalyzer.fillPercentage(grid: grid)
        )
        recentPlacements.append(record)
        if recentPlacements.count > windowSize {
            recentPlacements.removeFirst()
        }
        updatePressureScore()
    }

    // Legacy compatibility
    func recordPlacement(didClearLines: Bool) {
        let record = PlacementRecord(
            didClearLine: didClearLines,
            cellsCleared: didClearLines ? 8 : 0,
            wasNearMiss: false,
            boardFillPercentage: 0.5
        )
        recentPlacements.append(record)
        if recentPlacements.count > windowSize {
            recentPlacements.removeFirst()
        }
        updatePressureScore()
    }

    private func updatePressureScore() {
        guard recentPlacements.count >= 4 else { return }

        let clearRate = Double(recentPlacements.filter { $0.didClearLine }.count)
            / Double(recentPlacements.count)

        let avgFill = recentPlacements.map(\.boardFillPercentage).reduce(0, +)
            / Double(recentPlacements.count)

        // pressureScore: higher = player is doing well
        pressureScore = (clearRate * 0.6) + ((1.0 - avgFill) * 0.4)
        pressureScore = max(0.0, min(1.0, pressureScore))
    }

    // MARK: - Struggling (< 0.25): Be generous

    private func generateStrugglingPieces(count: Int, grid: GridModel) -> [BlockPiece] {
        let easyShapes: [PieceShape] = [.single, .domino, .triomino, .square2x2, .corner2x2]
        let allShapes = PieceShape.allCases
        var pieces: [BlockPiece] = []

        for i in 0..<count {
            let shape: PieceShape
            if i == 0 || Double.random(in: 0...1) < 0.8 {
                // 80% chance of easy shape
                shape = easyShapes.randomElement() ?? .triomino
            } else {
                shape = allShapes.randomElement() ?? .triomino
            }
            let color = BlockColor.allCases.randomElement() ?? .red
            pieces.append(BlockPiece(shape: shape, color: color))
        }

        // Guarantee at least 1 fits easily
        if !pieces.contains(where: { grid.canPlacePieceAnywhere($0) }) {
            if let fit = findPlaceablePiece(grid: grid, preferEasy: true) {
                pieces[0] = fit
            }
        }

        return pieces
    }

    // MARK: - Flow State (0.25 - 0.60): Standard distribution

    private func generateFlowPieces(count: Int, grid: GridModel) -> [BlockPiece] {
        var pieces: [BlockPiece] = []
        for _ in 0..<count {
            let shape = PieceShape.allCases.randomElement() ?? .triomino
            let color = BlockColor.allCases.randomElement() ?? .red
            pieces.append(BlockPiece(shape: shape, color: color))
        }
        return pieces
    }

    // MARK: - Dominating (> 0.60): Push back

    private func generateDominatingPieces(count: Int, grid: GridModel) -> [BlockPiece] {
        let hardShapes: [PieceShape] = [.pentomino, .square3x3, .rect2x3, .tetromino,
                                         .lShapeRight, .lShapeLeft, .lShapeDown, .lShapeUp,
                                         .sShape, .zShape, .sShapeVertical, .zShapeVertical]
        let allShapes = PieceShape.allCases
        var pieces: [BlockPiece] = []

        for _ in 0..<count {
            let shape: PieceShape
            if Double.random(in: 0...1) < 0.65 {
                shape = hardShapes.randomElement() ?? .tetromino
            } else {
                shape = allShapes.randomElement() ?? .triomino
            }
            let color = BlockColor.allCases.randomElement() ?? .red
            pieces.append(BlockPiece(shape: shape, color: color))
        }

        // 60% chance at least one fits
        if Double.random(in: 0...1) < 0.6 {
            if !pieces.contains(where: { grid.canPlacePieceAnywhere($0) }) {
                if let fit = findPlaceablePiece(grid: grid) {
                    pieces[0] = fit
                }
            }
        }

        return pieces
    }

    // MARK: - Crushing (> 0.80): Placement order matters

    private func generateCrushingPieces(count: Int, grid: GridModel) -> [BlockPiece] {
        // First generate hard pieces
        var pieces = generateDominatingPieces(count: count, grid: grid)

        // Try to create a set where placing piece A first blocks piece B's only spot
        // This creates strategic tension
        if pieces.count >= 2 {
            let snapshot = grid.snapshot()
            let simGrid = GridModel()
            simGrid.restore(from: snapshot)

            // Check if placing piece[0] reduces placements for piece[1]
            let p1PlacementsBefore = BoardAnalyzer.validPlacements(for: pieces[1], on: simGrid).count

            if let bestSpot = BoardAnalyzer.validPlacements(for: pieces[0], on: simGrid).randomElement() {
                simGrid.placePiece(pieces[0], at: bestSpot)
                let p1PlacementsAfter = BoardAnalyzer.validPlacements(for: pieces[1], on: simGrid).count

                // Good — piece order creates tension
                if p1PlacementsAfter < p1PlacementsBefore && p1PlacementsAfter > 0 {
                    // Keep this set — it naturally creates the puzzle-within-puzzle
                    logger.debug("Crushing set: placing piece 0 reduces piece 1 options from \(p1PlacementsBefore) to \(p1PlacementsAfter)")
                }
            }
        }

        return pieces
    }

    // MARK: - Near-Death Rescue

    private func engineerNearDeathRescue(pieces: [BlockPiece], grid: GridModel) -> [BlockPiece] {
        var modifiedPieces = pieces

        // Try to include at least one piece that CAN clear a line if placed optimally
        for (index, piece) in modifiedPieces.enumerated() {
            let clearingMoves = BoardAnalyzer.placementsThatClearLines(for: piece, on: grid)
            if !clearingMoves.isEmpty {
                // This piece already has a clearing opportunity — great
                logger.debug("Near-death rescue: piece \(index) has \(clearingMoves.count) clearing moves")
                return modifiedPieces
            }
        }

        // None of the pieces can clear — find one that can and swap it in
        let shuffledShapes = PieceShape.allCases.shuffled()
        for shape in shuffledShapes {
            let color = BlockColor.allCases.randomElement() ?? .red
            let candidate = BlockPiece(shape: shape, color: color)
            let clearingMoves = BoardAnalyzer.placementsThatClearLines(for: candidate, on: grid)
            if !clearingMoves.isEmpty && grid.canPlacePieceAnywhere(candidate) {
                modifiedPieces[0] = candidate
                logger.debug("Near-death rescue: swapped in \(shape.rawValue) with \(clearingMoves.count) clearing moves")
                return modifiedPieces
            }
        }

        return modifiedPieces
    }

    // MARK: - Tutorial Pieces

    private func generateTutorialPieces(count: Int, grid: GridModel) -> [BlockPiece] {
        let easyShapes: [PieceShape] = [.single, .domino, .triomino, .square2x2, .corner2x2]
        var pieces: [BlockPiece] = []

        for _ in 0..<count {
            let shape = easyShapes.randomElement() ?? .triomino
            let color = BlockColor.allCases.randomElement() ?? .blue
            let piece = BlockPiece(shape: shape, color: color)
            if grid.canPlacePieceAnywhere(piece) {
                pieces.append(piece)
            } else if let fit = findPlaceablePiece(grid: grid, preferEasy: true) {
                pieces.append(fit)
            } else {
                pieces.append(piece)
            }
        }
        return pieces
    }

    // MARK: - Helpers

    private func findPlaceablePiece(grid: GridModel, preferEasy: Bool = false) -> BlockPiece? {
        let shapes: [PieceShape]
        if preferEasy {
            shapes = [.single, .domino, .triomino, .square2x2, .corner2x2] + PieceShape.allCases.shuffled()
        } else {
            shapes = PieceShape.allCases.shuffled()
        }

        for shape in shapes {
            let color = BlockColor.allCases.randomElement() ?? .red
            let piece = BlockPiece(shape: shape, color: color)
            if grid.canPlacePieceAnywhere(piece) {
                return piece
            }
        }
        return nil
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

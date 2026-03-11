import Foundation

// MARK: - Board Analyzer
// Internal utility for adaptive difficulty — never shown to the player

struct BoardAnalyzer {

    /// All valid positions where the piece could be placed
    static func validPlacements(for piece: BlockPiece, on grid: GridModel) -> [GridPosition] {
        var positions: [GridPosition] = []
        for row in 0..<GridModel.gridSize {
            for col in 0..<GridModel.gridSize {
                let pos = GridPosition(row: row, col: col)
                if grid.canPlacePiece(piece, at: pos) {
                    positions.append(pos)
                }
            }
        }
        return positions
    }

    /// Positions where placing the piece would clear at least one line
    static func placementsThatClearLines(for piece: BlockPiece, on grid: GridModel) -> [GridPosition] {
        let allValid = validPlacements(for: piece, on: grid)
        var clearing: [GridPosition] = []

        for pos in allValid {
            // Simulate placement
            let snapshot = grid.snapshot()
            let simGrid = GridModel()
            simGrid.restore(from: snapshot)
            simGrid.placePiece(piece, at: pos)

            // Check if any lines would clear
            let wouldClearRows = (0..<GridModel.gridSize).contains { row in
                (0..<GridModel.gridSize).allSatisfy { simGrid.getCell(row: row, col: $0) != nil }
            }
            let wouldClearCols = (0..<GridModel.gridSize).contains { col in
                (0..<GridModel.gridSize).allSatisfy { simGrid.getCell(row: $0, col: col) != nil }
            }

            if wouldClearRows || wouldClearCols {
                clearing.append(pos)
            }
        }
        return clearing
    }

    /// 0.0 = safe, 1.0 = death is imminent
    static func boardDangerLevel(grid: GridModel, pieces: [BlockPiece]) -> Double {
        let totalCells = GridModel.gridSize * GridModel.gridSize
        let filled = grid.filledCellCount()
        let fillRatio = Double(filled) / Double(totalCells)

        // How many pieces can be placed?
        let placeablePieces = pieces.filter { grid.canPlacePieceAnywhere($0) }.count
        let placeabilityFactor: Double
        switch placeablePieces {
        case 0: placeabilityFactor = 1.0
        case 1: placeabilityFactor = 0.7
        case 2: placeabilityFactor = 0.3
        default: placeabilityFactor = 0.0
        }

        // Average valid placements per piece (fewer = more dangerous)
        let avgPlacements = pieces.isEmpty ? 0.0 :
            Double(pieces.map { validPlacements(for: $0, on: grid).count }.reduce(0, +)) / Double(pieces.count)
        let placementScarcity = max(0, 1.0 - (avgPlacements / 20.0)) // 20+ placements = safe

        return min(1.0, fillRatio * 0.4 + placeabilityFactor * 0.35 + placementScarcity * 0.25)
    }

    /// Best scoring move for a piece (greedy — most cells cleared)
    static func optimalPlacement(for piece: BlockPiece, on grid: GridModel) -> GridPosition? {
        let clearingMoves = placementsThatClearLines(for: piece, on: grid)
        if let best = clearingMoves.first {
            return best
        }
        // If no clearing move, pick the most "central" valid position
        let allValid = validPlacements(for: piece, on: grid)
        let center = GridModel.gridSize / 2
        return allValid.min(by: {
            abs($0.row - center) + abs($0.col - center) < abs($1.row - center) + abs($1.col - center)
        })
    }

    /// Board fill percentage (0.0 to 1.0)
    static func fillPercentage(grid: GridModel) -> Double {
        Double(grid.filledCellCount()) / Double(GridModel.gridSize * GridModel.gridSize)
    }

    /// Check if a piece placement is a "near miss" — only 1-2 valid spots on the whole board
    static func isNearMiss(for piece: BlockPiece, on grid: GridModel) -> Bool {
        let count = validPlacements(for: piece, on: grid).count
        return count >= 1 && count <= 2
    }

    /// Check if a piece is a "tight fit" — placed with 3+ occupied neighbors
    static func isTightFit(piece: BlockPiece, at position: GridPosition, on grid: GridModel) -> Bool {
        var adjacentOccupied = 0
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for cell in piece.cells {
            let r = position.row + cell.row
            let c = position.col + cell.col
            for (dr, dc) in directions {
                let nr = r + dr
                let nc = c + dc
                guard grid.isValidPosition(row: nr, col: nc) else {
                    adjacentOccupied += 1 // board edge counts
                    continue
                }
                // Check if neighbor is occupied AND not part of the piece itself
                let isPartOfPiece = piece.cells.contains(where: {
                    position.row + $0.row == nr && position.col + $0.col == nc
                })
                if !isPartOfPiece && grid.getCell(row: nr, col: nc) != nil {
                    adjacentOccupied += 1
                }
            }
        }
        return adjacentOccupied >= 3
    }
}

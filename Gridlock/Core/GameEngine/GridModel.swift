import Foundation
import os.log

// MARK: - Block Type

enum BlockColor: Int, Codable, CaseIterable {
    case red = 0, blue, green, yellow, purple

    var index: Int { rawValue }
}

// MARK: - Clear Result

struct ClearResult {
    let clearedRows: [Int]
    let clearedColumns: [Int]
    let cellsCleared: Int
    let baseScore: Int
    let simultaneousMultiplier: Int
    let comboMultiplier: Int
    let totalScore: Int
    let clearedPositions: Set<GridPosition>

    var totalLinesCleared: Int { clearedRows.count + clearedColumns.count }
    var isEmpty: Bool { clearedRows.isEmpty && clearedColumns.isEmpty }

    static let none = ClearResult(
        clearedRows: [], clearedColumns: [], cellsCleared: 0,
        baseScore: 0, simultaneousMultiplier: 1, comboMultiplier: 1,
        totalScore: 0, clearedPositions: []
    )
}

// MARK: - Grid Position

struct GridPosition: Hashable, Codable {
    let row: Int
    let col: Int

    static func + (lhs: GridPosition, rhs: GridPosition) -> GridPosition {
        GridPosition(row: lhs.row + rhs.row, col: lhs.col + rhs.col)
    }
}

// MARK: - Grid Model

final class GridModel: ObservableObject {
    static let gridSize = 8

    @Published private(set) var cells: [[BlockColor?]]
    private let logger = Logger(subsystem: "com.gridlock.app", category: "GridModel")

    var size: Int { Self.gridSize }

    init() {
        cells = Array(repeating: Array(repeating: nil, count: Self.gridSize), count: Self.gridSize)
    }

    // MARK: - State Management

    func reset() {
        cells = Array(repeating: Array(repeating: nil, count: Self.gridSize), count: Self.gridSize)
    }

    func setCell(row: Int, col: Int, color: BlockColor?) {
        guard isValidPosition(row: row, col: col) else { return }
        cells[row][col] = color
    }

    func getCell(row: Int, col: Int) -> BlockColor? {
        guard isValidPosition(row: row, col: col) else { return nil }
        return cells[row][col]
    }

    func isValidPosition(row: Int, col: Int) -> Bool {
        row >= 0 && row < Self.gridSize && col >= 0 && col < Self.gridSize
    }

    // MARK: - Piece Placement

    func canPlacePiece(_ piece: BlockPiece, at origin: GridPosition) -> Bool {
        for offset in piece.cells {
            let row = origin.row + offset.row
            let col = origin.col + offset.col
            guard isValidPosition(row: row, col: col), cells[row][col] == nil else {
                return false
            }
        }
        return true
    }

    func canPlacePieceAnywhere(_ piece: BlockPiece) -> Bool {
        for row in 0..<Self.gridSize {
            for col in 0..<Self.gridSize {
                if canPlacePiece(piece, at: GridPosition(row: row, col: col)) {
                    return true
                }
            }
        }
        return false
    }

    @discardableResult
    func placePiece(_ piece: BlockPiece, at origin: GridPosition) -> Bool {
        guard canPlacePiece(piece, at: origin) else { return false }

        for offset in piece.cells {
            let row = origin.row + offset.row
            let col = origin.col + offset.col
            cells[row][col] = piece.color
        }

        logger.debug("Placed \(piece.shape.rawValue) at (\(origin.row), \(origin.col))")
        return true
    }

    // MARK: - Line Clearing

    func checkAndClearLines(comboCount: Int) -> ClearResult {
        var rowsToClear: [Int] = []
        var colsToClear: [Int] = []

        // Check rows
        for row in 0..<Self.gridSize {
            if (0..<Self.gridSize).allSatisfy({ cells[row][$0] != nil }) {
                rowsToClear.append(row)
            }
        }

        // Check columns
        for col in 0..<Self.gridSize {
            if (0..<Self.gridSize).allSatisfy({ cells[$0][col] != nil }) {
                colsToClear.append(col)
            }
        }

        guard !rowsToClear.isEmpty || !colsToClear.isEmpty else {
            return .none
        }

        // Collect positions before clearing
        var clearedPositions = Set<GridPosition>()
        for row in rowsToClear {
            for col in 0..<Self.gridSize {
                clearedPositions.insert(GridPosition(row: row, col: col))
            }
        }
        for col in colsToClear {
            for row in 0..<Self.gridSize {
                clearedPositions.insert(GridPosition(row: row, col: col))
            }
        }

        // Clear the cells
        for pos in clearedPositions {
            cells[pos.row][pos.col] = nil
        }

        let totalLines = rowsToClear.count + colsToClear.count
        let cellsCleared = clearedPositions.count

        // Score calculation
        let baseCellScore = cellsCleared * 10
        let lineBonus = totalLines * 100

        let simultaneousMultiplier: Int
        switch totalLines {
        case 1: simultaneousMultiplier = 1
        case 2: simultaneousMultiplier = 3
        case 3: simultaneousMultiplier = 6
        default: simultaneousMultiplier = 10
        }

        let comboMultiplier = min(comboCount + 1, 5)
        let totalScore = (baseCellScore + lineBonus) * simultaneousMultiplier * comboMultiplier

        logger.info("Cleared \(totalLines) lines (\(rowsToClear.count)R, \(colsToClear.count)C), combo=\(comboMultiplier)x, score=\(totalScore)")

        return ClearResult(
            clearedRows: rowsToClear,
            clearedColumns: colsToClear,
            cellsCleared: cellsCleared,
            baseScore: baseCellScore + lineBonus,
            simultaneousMultiplier: simultaneousMultiplier,
            comboMultiplier: comboMultiplier,
            totalScore: totalScore,
            clearedPositions: clearedPositions
        )
    }

    // MARK: - Game Over Detection

    func isGameOver(availablePieces: [BlockPiece]) -> Bool {
        for piece in availablePieces {
            if canPlacePieceAnywhere(piece) {
                return false
            }
        }
        return true
    }

    // MARK: - Utility

    func filledCellCount() -> Int {
        cells.flatMap { $0 }.compactMap { $0 }.count
    }

    func emptyCellCount() -> Int {
        Self.gridSize * Self.gridSize - filledCellCount()
    }

    func snapshot() -> [[BlockColor?]] {
        cells.map { $0 }
    }

    func restore(from snapshot: [[BlockColor?]]) {
        guard snapshot.count == Self.gridSize,
              snapshot.allSatisfy({ $0.count == Self.gridSize }) else { return }
        cells = snapshot
    }

    /// Remove all blocks in a 3x3 area centered on the given position
    func clearArea(center: GridPosition, radius: Int = 1) -> Set<GridPosition> {
        var cleared = Set<GridPosition>()
        for dr in -radius...radius {
            for dc in -radius...radius {
                let r = center.row + dr
                let c = center.col + dc
                if isValidPosition(row: r, col: c), cells[r][c] != nil {
                    cells[r][c] = nil
                    cleared.insert(GridPosition(row: r, col: c))
                }
            }
        }
        return cleared
    }

    /// Clear an entire row
    func clearRow(_ row: Int) -> Set<GridPosition> {
        var cleared = Set<GridPosition>()
        guard row >= 0 && row < Self.gridSize else { return cleared }
        for col in 0..<Self.gridSize {
            if cells[row][col] != nil {
                cells[row][col] = nil
                cleared.insert(GridPosition(row: row, col: col))
            }
        }
        return cleared
    }

    /// Clear an entire column
    func clearColumn(_ col: Int) -> Set<GridPosition> {
        var cleared = Set<GridPosition>()
        guard col >= 0 && col < Self.gridSize else { return cleared }
        for row in 0..<Self.gridSize {
            if cells[row][col] != nil {
                cells[row][col] = nil
                cleared.insert(GridPosition(row: row, col: col))
            }
        }
        return cleared
    }

    /// Remove 2 random filled rows (for continue-after-game-over)
    func removeRandomFilledRows(count: Int = 2) -> [Int] {
        let filledRows = (0..<Self.gridSize).filter { row in
            (0..<Self.gridSize).contains { cells[row][$0] != nil }
        }
        let rowsToRemove = Array(filledRows.shuffled().prefix(count))
        for row in rowsToRemove {
            for col in 0..<Self.gridSize {
                cells[row][col] = nil
            }
        }
        return rowsToRemove
    }
}

import Foundation

// MARK: - Piece Shape

enum PieceShape: String, CaseIterable, Codable {
    case single
    case domino          // 1x2
    case triomino        // 1x3
    case tetromino       // 1x4
    case pentomino       // 1x5
    case square2x2
    case rect2x3
    case square3x3
    case lShapeRight     // L
    case lShapeLeft      // J
    case lShapeDown      // L rotated
    case lShapeUp        // J rotated
    case tShape
    case tShapeRight
    case tShapeDown
    case tShapeLeft
    case sShape
    case zShape
    case sShapeVertical
    case zShapeVertical
    case corner2x2       // 2x2 L shape (3 cells)

    var cells: [GridPosition] {
        switch self {
        case .single:
            return [GridPosition(row: 0, col: 0)]
        case .domino:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1)]
        case .triomino:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 0, col: 2)]
        case .tetromino:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1),
                    GridPosition(row: 0, col: 2), GridPosition(row: 0, col: 3)]
        case .pentomino:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1),
                    GridPosition(row: 0, col: 2), GridPosition(row: 0, col: 3),
                    GridPosition(row: 0, col: 4)]
        case .square2x2:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1),
                    GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1)]
        case .rect2x3:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 0, col: 2),
                    GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2)]
        case .square3x3:
            return (0..<3).flatMap { r in (0..<3).map { c in GridPosition(row: r, col: c) } }
        case .lShapeRight:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0),
                    GridPosition(row: 2, col: 0), GridPosition(row: 2, col: 1)]
        case .lShapeLeft:
            return [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 1),
                    GridPosition(row: 2, col: 1), GridPosition(row: 2, col: 0)]
        case .lShapeDown:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1),
                    GridPosition(row: 0, col: 2), GridPosition(row: 1, col: 0)]
        case .lShapeUp:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1),
                    GridPosition(row: 0, col: 2), GridPosition(row: 1, col: 2)]
        case .tShape:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1),
                    GridPosition(row: 0, col: 2), GridPosition(row: 1, col: 1)]
        case .tShapeRight:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0),
                    GridPosition(row: 2, col: 0), GridPosition(row: 1, col: 1)]
        case .tShapeDown:
            return [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 0),
                    GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2)]
        case .tShapeLeft:
            return [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 1),
                    GridPosition(row: 2, col: 1), GridPosition(row: 1, col: 0)]
        case .sShape:
            return [GridPosition(row: 0, col: 1), GridPosition(row: 0, col: 2),
                    GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1)]
        case .zShape:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1),
                    GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2)]
        case .sShapeVertical:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0),
                    GridPosition(row: 1, col: 1), GridPosition(row: 2, col: 1)]
        case .zShapeVertical:
            return [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 0),
                    GridPosition(row: 1, col: 1), GridPosition(row: 2, col: 0)]
        case .corner2x2:
            return [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0),
                    GridPosition(row: 1, col: 1)]
        }
    }

    var width: Int {
        (cells.map(\.col).max() ?? 0) + 1
    }

    var height: Int {
        (cells.map(\.row).max() ?? 0) + 1
    }

    /// Difficulty weight: higher = harder to place
    var difficultyWeight: Double {
        switch self {
        case .single: return 0.1
        case .domino: return 0.2
        case .triomino: return 0.3
        case .tetromino: return 0.5
        case .pentomino: return 0.8
        case .square2x2: return 0.3
        case .rect2x3: return 0.6
        case .square3x3: return 0.9
        case .lShapeRight, .lShapeLeft, .lShapeDown, .lShapeUp: return 0.5
        case .tShape, .tShapeRight, .tShapeDown, .tShapeLeft: return 0.5
        case .sShape, .zShape, .sShapeVertical, .zShapeVertical: return 0.6
        case .corner2x2: return 0.3
        }
    }
}

// MARK: - Block Piece

struct BlockPiece: Identifiable, Equatable {
    let id: UUID
    let shape: PieceShape
    let color: BlockColor
    var cells: [GridPosition] { shape.cells }
    var width: Int { shape.width }
    var height: Int { shape.height }
    var cellCount: Int { cells.count }

    init(shape: PieceShape, color: BlockColor, id: UUID = UUID()) {
        self.id = id
        self.shape = shape
        self.color = color
    }

    static func == (lhs: BlockPiece, rhs: BlockPiece) -> Bool {
        lhs.id == rhs.id
    }

    static let allShapes = PieceShape.allCases

    static let palette: [BlockColor] = BlockColor.allCases
}

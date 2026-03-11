import Foundation
import Combine
import os.log

// MARK: - Game Phase

enum GamePhase: Equatable {
    case menu
    case playing
    case paused
    case gameOver
    case tutorial(step: Int)
    case dailyChallenge
    case powerUpMode(PowerUpType)
}

// MARK: - Game State

final class GameState: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var grid: GridModel
    @Published var scoreEngine: ScoreEngine
    @Published var availablePieces: [BlockPiece?] = [nil, nil, nil]
    @Published var activePowerUps: [PowerUpType: Int] = [:]
    @Published var elapsedTime: TimeInterval = 0
    @Published var isNewHighScore: Bool = false
    @Published var lastClearResult: ClearResult?
    @Published var lastScoreEvent: ScoreEvent?

    let pieceGenerator: PieceGenerator
    let powerUpSystem: PowerUpSystem

    private var gridSnapshot: [[BlockColor?]]?
    private var lastPiecePlaced: (piece: BlockPiece, position: GridPosition)?
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.gridlock.app", category: "GameState")

    var isPlaying: Bool { phase == .playing || phase == .dailyChallenge }
    var isPowerUpMode: Bool {
        if case .powerUpMode = phase { return true }
        return false
    }

    init() {
        self.grid = GridModel()
        self.scoreEngine = ScoreEngine()
        self.pieceGenerator = PieceGenerator()
        self.powerUpSystem = PowerUpSystem()
    }

    // MARK: - Game Lifecycle

    func startNewGame() {
        grid.reset()
        scoreEngine.reset()
        elapsedTime = 0
        isNewHighScore = false
        lastClearResult = nil
        lastScoreEvent = nil
        gridSnapshot = nil
        lastPiecePlaced = nil

        let isFirstGame = UserDefaults.standard.integer(forKey: "totalGamesPlayed") == 0
        pieceGenerator.isTutorialMode = isFirstGame

        phase = .playing
        generateNewPieces()
        startTimer()

        logger.info("New game started, tutorial=\(isFirstGame)")
    }

    func startDailyChallenge(board: [[BlockColor?]], pieces: [BlockPiece]) {
        grid.reset()
        grid.restore(from: board)
        scoreEngine.reset()
        elapsedTime = 0
        isNewHighScore = false

        availablePieces = pieces.map { Optional($0) }
        phase = .dailyChallenge
        startTimer()

        logger.info("Daily challenge started")
    }

    func pause() {
        guard isPlaying else { return }
        phase = .paused
        stopTimer()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        startTimer()
    }

    func gameOver() {
        phase = .gameOver
        stopTimer()
        isNewHighScore = scoreEngine.checkHighScore()

        // Track stats
        let gamesPlayed = UserDefaults.standard.integer(forKey: "totalGamesPlayed") + 1
        UserDefaults.standard.set(gamesPlayed, forKey: "totalGamesPlayed")

        pieceGenerator.isTutorialMode = false

        logger.info("Game over. Score=\(self.scoreEngine.currentScore), high=\(self.scoreEngine.highScore), newHigh=\(self.isNewHighScore)")
    }

    func returnToMenu() {
        phase = .menu
        stopTimer()
    }

    // MARK: - Piece Management

    func generateNewPieces() {
        let pieces = pieceGenerator.generatePieces(count: 3, grid: grid)
        availablePieces = pieces.map { Optional($0) }
    }

    var remainingPieceCount: Int {
        availablePieces.compactMap { $0 }.count
    }

    func removePiece(at index: Int) {
        guard index >= 0 && index < availablePieces.count else { return }
        availablePieces[index] = nil
    }

    func allPiecesPlaced() -> Bool {
        availablePieces.allSatisfy { $0 == nil }
    }

    // MARK: - Piece Placement

    func placePiece(_ piece: BlockPiece, at position: GridPosition, trayIndex: Int) -> ClearResult? {
        // Save snapshot for undo
        gridSnapshot = grid.snapshot()
        lastPiecePlaced = (piece, position)

        guard grid.placePiece(piece, at: position) else { return nil }

        removePiece(at: trayIndex)
        scoreEngine.addPlacementScore(cellCount: piece.cellCount)

        // Check for line clears
        let result = grid.checkAndClearLines(comboCount: scoreEngine.comboCount)
        let scoreEvent = scoreEngine.processClearResult(result)

        lastClearResult = result
        lastScoreEvent = scoreEvent

        // Track for adaptive difficulty
        pieceGenerator.recordPlacement(didClearLines: !result.isEmpty, cellsCleared: result.cellsCleared, grid: grid)

        // Check for power-up drops
        if !result.isEmpty {
            powerUpSystem.checkForDrop(linesCleared: result.totalLinesCleared, comboCount: scoreEngine.comboCount)
        }

        // Check point-based power-up drop
        powerUpSystem.checkPointDrop(totalScore: scoreEngine.currentScore)

        // If no lines cleared, reset combo
        if result.isEmpty {
            scoreEngine.resetCombo()
        }

        // Generate new pieces if all placed
        if allPiecesPlaced() {
            generateNewPieces()
        }

        // Check game over
        let activePieces = availablePieces.compactMap { $0 }
        if grid.isGameOver(availablePieces: activePieces) {
            gameOver()
        }

        return result
    }

    // MARK: - Undo

    func canUndo() -> Bool {
        gridSnapshot != nil && lastPiecePlaced != nil
    }

    func performUndo() -> (piece: BlockPiece, position: GridPosition)? {
        guard let snapshot = gridSnapshot, let last = lastPiecePlaced else { return nil }
        grid.restore(from: snapshot)
        gridSnapshot = nil

        // Return piece to tray
        if let emptyIndex = availablePieces.firstIndex(where: { $0 == nil }) {
            availablePieces[emptyIndex] = last.piece
        }

        let result = last
        lastPiecePlaced = nil
        return result
    }

    // MARK: - Continue After Game Over

    func continueAfterAd() {
        let removedRows = grid.removeRandomFilledRows(count: 2)
        phase = .playing
        startTimer()

        // Generate new pieces if needed
        if allPiecesPlaced() {
            generateNewPieces()
        }

        logger.info("Continued after ad, removed rows: \(removedRows)")
    }

    // MARK: - Power-Up Activation

    func enterPowerUpMode(_ type: PowerUpType) {
        guard powerUpSystem.canUse(type) else { return }
        phase = .powerUpMode(type)
    }

    func cancelPowerUpMode() {
        guard isPowerUpMode else { return }
        phase = .playing
    }

    func executePowerUp(_ type: PowerUpType, target: GridPosition? = nil) -> Set<GridPosition> {
        guard powerUpSystem.use(type) else { return [] }

        var affected = Set<GridPosition>()

        switch type {
        case .bomb:
            if let target = target {
                affected = grid.clearArea(center: target, radius: 1)
            }
        case .lineBlast:
            if let target = target {
                // Clear the row or column with more filled cells
                let rowCount = (0..<GridModel.gridSize).filter { grid.getCell(row: target.row, col: $0) != nil }.count
                let colCount = (0..<GridModel.gridSize).filter { grid.getCell(row: $0, col: target.col) != nil }.count
                if rowCount >= colCount {
                    affected = grid.clearRow(target.row)
                } else {
                    affected = grid.clearColumn(target.col)
                }
            }
        case .undo:
            if let _ = performUndo() {
                // Undo handled above
            }
        case .shuffle:
            generateNewPieces()
        }

        phase = .playing
        return affected
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Serialization

    func save() {
        let data = GameSaveData(
            grid: grid.snapshot(),
            score: scoreEngine.currentScore,
            piecesPlaced: scoreEngine.totalPiecesPlaced,
            linesCleared: scoreEngine.totalLinesCleared,
            combo: scoreEngine.comboCount,
            elapsedTime: elapsedTime
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "savedGameState")
        }
    }

    func loadSavedGame() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "savedGameState"),
              let saved = try? JSONDecoder().decode(GameSaveData.self, from: data) else {
            return false
        }
        grid.restore(from: saved.grid)
        elapsedTime = saved.elapsedTime
        return true
    }

    func clearSavedGame() {
        UserDefaults.standard.removeObject(forKey: "savedGameState")
    }
}

// MARK: - Save Data

struct GameSaveData: Codable {
    let grid: [[BlockColor?]]
    let score: Int
    let piecesPlaced: Int
    let linesCleared: Int
    let combo: Int
    let elapsedTime: TimeInterval
}

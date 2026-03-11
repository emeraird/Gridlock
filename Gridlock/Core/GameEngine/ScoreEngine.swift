import Foundation
import os.log

// MARK: - Reinforcement Message

enum ReinforcementMessage: String {
    case nice = "Nice!"
    case great = "Great!"
    case amazing = "Amazing!"
    case incredible = "INCREDIBLE!"
    case unbelievable = "UNBELIEVABLE!"

    var intensity: Int {
        switch self {
        case .nice: return 1
        case .great: return 2
        case .amazing: return 3
        case .incredible: return 4
        case .unbelievable: return 5
        }
    }

    static func forLineCount(_ count: Int) -> ReinforcementMessage {
        switch count {
        case 1: return .nice
        case 2: return .great
        case 3: return .amazing
        case 4: return .incredible
        default: return .unbelievable
        }
    }
}

// MARK: - Score Event

struct ScoreEvent {
    let points: Int
    let message: ReinforcementMessage?
    let comboLevel: Int
    let linesCleared: Int
    let isNewHighScore: Bool
}

// MARK: - Score Engine

final class ScoreEngine: ObservableObject {
    @Published private(set) var currentScore: Int = 0
    @Published private(set) var highScore: Int = 0
    @Published private(set) var comboCount: Int = 0
    @Published private(set) var totalLinesCleared: Int = 0
    @Published private(set) var totalPiecesPlaced: Int = 0
    @Published private(set) var maxCombo: Int = 0

    private let logger = Logger(subsystem: "com.gridlock.app", category: "ScoreEngine")
    private let highScoreKey = "highScore"

    init() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }

    func reset() {
        currentScore = 0
        comboCount = 0
        totalLinesCleared = 0
        totalPiecesPlaced = 0
        maxCombo = 0
    }

    // MARK: - Score Calculation

    func processClearResult(_ result: ClearResult) -> ScoreEvent {
        guard !result.isEmpty else {
            // No lines cleared - reset combo
            comboCount = 0
            return ScoreEvent(points: 0, message: nil, comboLevel: 0, linesCleared: 0, isNewHighScore: false)
        }

        currentScore += result.totalScore
        totalLinesCleared += result.totalLinesCleared
        comboCount += 1
        maxCombo = max(maxCombo, comboCount)

        let isNewHigh = currentScore > highScore
        if isNewHigh {
            highScore = currentScore
            UserDefaults.standard.set(highScore, forKey: highScoreKey)
        }

        let message = ReinforcementMessage.forLineCount(result.totalLinesCleared)

        logger.info("Score: \(self.currentScore) (+\(result.totalScore)), combo=\(self.comboCount), lines=\(result.totalLinesCleared)")

        return ScoreEvent(
            points: result.totalScore,
            message: message,
            comboLevel: comboCount,
            linesCleared: result.totalLinesCleared,
            isNewHighScore: isNewHigh
        )
    }

    func addPlacementScore(cellCount: Int) {
        let placementBonus = cellCount * 5
        currentScore += placementBonus
        totalPiecesPlaced += 1
    }

    func addBonusPoints(_ points: Int) {
        currentScore += points
        logger.info("Bonus points: +\(points), total=\(self.currentScore)")
    }

    func resetCombo() {
        comboCount = 0
    }

    // MARK: - Combo Message

    func comboMessage() -> String? {
        guard comboCount >= 2 else { return nil }
        return "COMBO x\(min(comboCount, 5))!"
    }

    // MARK: - High Score

    func checkHighScore() -> Bool {
        if currentScore > highScore {
            highScore = currentScore
            UserDefaults.standard.set(highScore, forKey: highScoreKey)
            return true
        }
        return false
    }

    func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }
}

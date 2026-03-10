import Foundation
import Combine
import os.log

// MARK: - Power-Up Type

enum PowerUpType: String, CaseIterable, Codable {
    case bomb
    case lineBlast
    case undo
    case shuffle

    var displayName: String {
        switch self {
        case .bomb: return "Bomb"
        case .lineBlast: return "Line Blast"
        case .undo: return "Undo"
        case .shuffle: return "Shuffle"
        }
    }

    var iconName: String {
        switch self {
        case .bomb: return "flame.fill"
        case .lineBlast: return "bolt.fill"
        case .undo: return "arrow.uturn.backward"
        case .shuffle: return "shuffle"
        }
    }

    /// Drop rate relative weight
    var dropWeight: Double {
        switch self {
        case .bomb: return 50
        case .lineBlast: return 30
        case .undo: return 15
        case .shuffle: return 5
        }
    }

    static let maxInventory = 5
}

// MARK: - Power-Up Event

struct PowerUpEarnedEvent {
    let type: PowerUpType
    let reason: String
}

// MARK: - Power-Up System

final class PowerUpSystem: ObservableObject {
    @Published private(set) var inventory: [PowerUpType: Int] = [:]

    private let logger = Logger(subsystem: "com.gridlock.app", category: "PowerUpSystem")
    private let storageKey = "powerUpInventory"
    private var lastPointDropThreshold: Int = 0

    // Publisher for UI to react to power-up earned events
    let earnedPublisher = PassthroughSubject<PowerUpEarnedEvent, Never>()

    init() {
        loadInventory()
    }

    // MARK: - Inventory

    func count(of type: PowerUpType) -> Int {
        inventory[type] ?? 0
    }

    func canUse(_ type: PowerUpType) -> Bool {
        count(of: type) > 0
    }

    @discardableResult
    func use(_ type: PowerUpType) -> Bool {
        guard canUse(type) else { return false }
        inventory[type] = count(of: type) - 1
        saveInventory()
        logger.info("Used \(type.rawValue), remaining=\(self.count(of: type))")
        return true
    }

    func earn(_ type: PowerUpType, reason: String = "") {
        let current = count(of: type)
        guard current < PowerUpType.maxInventory else {
            logger.debug("Inventory full for \(type.rawValue)")
            return
        }
        inventory[type] = current + 1
        saveInventory()
        earnedPublisher.send(PowerUpEarnedEvent(type: type, reason: reason))
        logger.info("Earned \(type.rawValue) (\(reason)), now=\(self.count(of: type))")
    }

    func addPack() {
        for type in PowerUpType.allCases {
            let current = count(of: type)
            inventory[type] = min(current + 5, PowerUpType.maxInventory)
        }
        saveInventory()
    }

    // MARK: - Drop Logic

    func checkForDrop(linesCleared: Int, comboCount: Int) {
        // Clearing 2+ lines simultaneously earns a power-up
        if linesCleared >= 2 {
            let type = randomPowerUp()
            earn(type, reason: "cleared \(linesCleared) lines")
        }

        // Combo chain of 3+ earns a power-up
        if comboCount >= 3 {
            let type = randomPowerUp()
            earn(type, reason: "combo x\(comboCount)")
        }
    }

    func checkPointDrop(totalScore: Int) {
        // Every 500 points, 30% chance of a power-up
        let threshold = (totalScore / 500) * 500
        guard threshold > lastPointDropThreshold else { return }
        lastPointDropThreshold = threshold

        if Double.random(in: 0...1) < 0.3 {
            let type = randomPowerUp()
            earn(type, reason: "score milestone \(threshold)")
        }
    }

    func resetPointTracking() {
        lastPointDropThreshold = 0
    }

    // MARK: - Random Selection

    private func randomPowerUp() -> PowerUpType {
        let totalWeight = PowerUpType.allCases.reduce(0.0) { $0 + $1.dropWeight }
        var roll = Double.random(in: 0..<totalWeight)

        for type in PowerUpType.allCases {
            roll -= type.dropWeight
            if roll <= 0 {
                return type
            }
        }
        return .bomb
    }

    // MARK: - Persistence

    private func saveInventory() {
        let data = inventory.mapKeys { $0.rawValue }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadInventory() {
        guard let data = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] else { return }
        for (key, value) in data {
            if let type = PowerUpType(rawValue: key) {
                inventory[type] = min(value, PowerUpType.maxInventory)
            }
        }
    }
}

// MARK: - Dictionary Helper

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}

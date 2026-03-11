import Foundation
import Combine

// MARK: - Zone State Manager
// Tracks combo escalation and the "Zone" state (combo 4+)

final class ZoneStateManager: ObservableObject {
    @Published private(set) var isInZone: Bool = false
    @Published private(set) var comboLevel: Int = 0
    @Published private(set) var bestComboEver: Int = 0
    @Published private(set) var bestComboThisGame: Int = 0

    private let bestComboKey = "bestComboEver"

    // Zone visual intensity (0.0 to 1.0)
    var zoneIntensity: Double {
        guard isInZone else { return 0 }
        return min(1.0, Double(comboLevel - 3) / 4.0) // ramps from 4 to 7+
    }

    init() {
        bestComboEver = UserDefaults.standard.integer(forKey: bestComboKey)
    }

    // MARK: - Combo Tracking

    func onComboHit(level: Int) {
        comboLevel = level
        bestComboThisGame = max(bestComboThisGame, level)

        let wasInZone = isInZone

        if level >= 4 && !wasInZone {
            isInZone = true
        }

        // Check best combo record
        if level > bestComboEver {
            bestComboEver = level
            UserDefaults.standard.set(bestComboEver, forKey: bestComboKey)
        }
    }

    func onComboBreak() {
        let wasInZone = isInZone
        isInZone = false
        comboLevel = 0

        if wasInZone {
            // Zone exit — the loss should feel bad
        }
    }

    func resetForNewGame() {
        isInZone = false
        comboLevel = 0
        bestComboThisGame = 0
    }

    // MARK: - Combo Messages

    var comboMessage: String? {
        switch comboLevel {
        case 1: return "Nice!"
        case 2: return "Great!"
        case 3: return "AMAZING!"
        case 4: return "🔥 ZONE!"
        case 5: return "UNSTOPPABLE!"
        case 6: return "LEGENDARY!"
        default:
            if comboLevel >= 7 { return "GODLIKE!" }
            return nil
        }
    }

    var tiedBestCombo: Bool {
        comboLevel == bestComboEver && comboLevel > 0 && comboLevel == bestComboThisGame
    }

    var newComboRecord: Bool {
        comboLevel > 0 && bestComboThisGame > (UserDefaults.standard.integer(forKey: bestComboKey))
    }

    // MARK: - Music Adjustments

    var musicPitchShift: Float {
        switch comboLevel {
        case 3: return 1.02    // +2%
        case 4: return 1.08    // +8%
        case 5: return 1.10
        case 6: return 1.12
        default:
            if comboLevel >= 7 { return 1.15 }
            return 1.0
        }
    }
}

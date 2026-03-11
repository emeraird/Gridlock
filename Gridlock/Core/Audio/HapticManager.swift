import UIKit
import os.log

final class HapticManager {
    static let shared = HapticManager()

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "hapticsEnabled") }
    }

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        prepareAll()
    }

    private func prepareAll() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        softGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Game Interactions

    /// Piece picked up from tray
    func piecePickup() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
    }

    /// Piece hovering over a new valid cell
    func hoverCell() {
        guard isEnabled else { return }
        softGenerator.impactOccurred(intensity: 0.3)
    }

    /// Piece successfully placed on the grid
    func piecePlaced() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
    }

    /// Line cleared
    func lineClear() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
    }

    /// Combo x2: double tap
    func combo2x() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            mediumGenerator.impactOccurred()
        }
    }

    /// Combo x3+: notification success
    func comboHigh() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    /// Power-up earned
    func powerUpEarned() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    /// Power-up activated
    func powerUpActivated() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [self] in
            notificationGenerator.notificationOccurred(.warning)
        }
    }

    /// Game over
    func gameOver() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    /// New high score: triple tap pattern
    func newHighScore() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            heavyGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                heavyGenerator.impactOccurred()
            }
        }
    }

    /// Button press
    func buttonTap() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
    }

    /// Invalid placement attempt
    func invalidPlacement() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    /// Selection change (e.g., settings toggle)
    func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    /// Generic combo haptic based on level
    func comboHaptic(level: Int) {
        switch level {
        case 2: combo2x()
        case 3: comboHigh()
        case 4: zoneEntry()
        case 5...: zoneCombo(level: level)
        default: break
        }
    }

    // MARK: - Zone Haptics

    /// Entering the Zone (combo 4+): escalating triple burst
    func zoneEntry() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [self] in
            heavyGenerator.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [self] in
                notificationGenerator.notificationOccurred(.success)
            }
        }
    }

    /// Zone combo (5+): rhythmic pulse pattern
    func zoneCombo(level: Int) {
        guard isEnabled else { return }
        let count = min(level - 2, 5)
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) { [self] in
                heavyGenerator.impactOccurred(intensity: min(1.0, 0.5 + Double(i) * 0.15))
            }
        }
    }

    /// Zone exit: descending pattern
    func zoneExit() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            mediumGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                lightGenerator.impactOccurred()
            }
        }
    }

    // MARK: - Milestone Haptics

    /// Milestone celebration: escalating fanfare pattern
    func milestoneCelebration() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            heavyGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                notificationGenerator.notificationOccurred(.success)
            }
        }
    }

    /// Daily reward collect: satisfying thunk
    func dailyRewardCollect() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
            notificationGenerator.notificationOccurred(.success)
        }
    }

    /// Near-death save: dramatic tension release
    func nearDeathSave() {
        guard isEnabled else { return }
        softGenerator.impactOccurred(intensity: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            mediumGenerator.impactOccurred()
        }
    }

    /// Tight fit placement: satisfying snap
    func tightFit() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            lightGenerator.impactOccurred(intensity: 0.6)
        }
    }
}

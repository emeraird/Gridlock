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
        case 3...: comboHigh()
        default: break
        }
    }
}

import SpriteKit

// MARK: - Tutorial Overlay

final class TutorialOverlay {
    private weak var scene: GameScene?
    private var currentStep = 0
    private var overlayNode: SKNode?
    private var arrowNode: SKNode?
    private var spotlightNode: SKShapeNode?
    private var messageNode: SKLabelNode?

    var isActive: Bool { overlayNode != nil }

    init(scene: GameScene) {
        self.scene = scene
    }

    // MARK: - Tutorial Flow

    func startTutorial() {
        guard let scene = scene else { return }
        currentStep = 0

        // The tutorial runs during actual gameplay (game is in .playing state)
        // We just add visual hints on top
        showStep(0)
    }

    func advanceStep() {
        currentStep += 1
        clearOverlay()

        switch currentStep {
        case 1:
            // After first piece placed — celebrate
            showCelebration("Great!")
            run(after: 1.0) { [weak self] in
                self?.clearOverlay()
                // Let player place 2 more pieces freely
            }

        case 2:
            // After first line clear
            showMessage("Clear rows and columns\nto score points!")
            run(after: 2.0) { [weak self] in
                self?.clearOverlay()
            }

        case 3:
            // Combo hint
            showMessage("Clear lines in a row\nfor COMBO bonuses!")
            run(after: 2.0) { [weak self] in
                self?.clearOverlay()
                self?.completeTutorial()
            }

        default:
            completeTutorial()
        }
    }

    func onPiecePlaced() {
        if currentStep == 0 {
            advanceStep()
        }
    }

    func onLineCleared() {
        if currentStep == 1 {
            currentStep = 1
            advanceStep()
        }
    }

    func onCombo() {
        if currentStep == 2 {
            advanceStep()
        }
    }

    // MARK: - Visual Hints

    private func showStep(_ step: Int) {
        guard let scene = scene else { return }

        switch step {
        case 0:
            // Show arrow pointing from first piece in tray to the grid
            guard let traySlot = scene.pieceTrays.first else { return }
            let slotPos = traySlot.convert(.zero, to: scene)

            showArrow(from: slotPos, direction: .up, in: scene)
            showMessage("Drag the piece\nonto the grid!")

        default:
            break
        }
    }

    private func showArrow(from position: CGPoint, direction: ArrowDirection, in scene: SKScene) {
        let arrow = SKNode()
        arrow.position = position
        arrow.zPosition = 95

        let shaft = SKSpriteNode(color: .white.withAlphaComponent(0.8),
                                  size: CGSize(width: 4, height: 40))
        shaft.position = CGPoint(x: 0, y: 20)
        arrow.addChild(shaft)

        // Arrowhead
        let head = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -10, y: 40))
        path.addLine(to: CGPoint(x: 0, y: 55))
        path.addLine(to: CGPoint(x: 10, y: 40))
        path.closeSubpath()
        head.path = path
        head.fillColor = .white.withAlphaComponent(0.8)
        head.strokeColor = .clear
        arrow.addChild(head)

        // Bobbing animation
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 8, duration: 0.4),
            SKAction.moveBy(x: 0, y: -8, duration: 0.4)
        ])
        arrow.run(SKAction.repeatForever(bob))

        scene.addChild(arrow)
        arrowNode = arrow
    }

    private func showMessage(_ text: String) {
        guard let scene = scene else { return }
        clearMessage()

        let label = SKLabelNode(text: text)
        label.fontName = "SF Pro Display Bold"
        label.fontSize = 20
        label.fontColor = .white
        label.numberOfLines = 2
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 - 80)
        label.zPosition = 95
        label.alpha = 0

        // Background pill
        let bgSize = CGSize(width: 260, height: 60)
        let bg = SKShapeNode(rectOf: bgSize, cornerRadius: 12)
        bg.fillColor = UIColor.black.withAlphaComponent(0.7)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: 0, y: 5)
        bg.zPosition = -1
        label.addChild(bg)

        scene.addChild(label)
        messageNode = label

        label.run(SKAction.fadeIn(withDuration: 0.3))
    }

    private func showCelebration(_ text: String) {
        guard let scene = scene else { return }

        let label = SKLabelNode(text: text)
        label.fontName = "SF Pro Display Heavy"
        label.fontSize = 40
        label.fontColor = .yellow
        label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        label.zPosition = 95
        label.setScale(0.5)
        label.alpha = 0
        scene.addChild(label)
        messageNode = label

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.bounceIn(to: 1.0, duration: 0.2)
            ]),
            SKAction.wait(forDuration: 0.8),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.moveBy(x: 0, y: 30, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))

        // Extra celebration particles for first game
        for _ in 0..<15 {
            let confetti = SKSpriteNode(color: [UIColor.yellow, .cyan, .green, .orange, .magenta].randomElement()!,
                                         size: CGSize(width: 5, height: 5))
            confetti.position = CGPoint(x: scene.size.width / 2 + CGFloat.random(in: -50...50),
                                        y: scene.size.height / 2 + 20)
            confetti.zPosition = 94
            scene.addChild(confetti)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            confetti.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * 80, y: sin(angle) * 80 + 30, duration: 0.6),
                    SKAction.fadeOut(withDuration: 0.6),
                    SKAction.rotate(byAngle: .pi * 2, duration: 0.6)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Cleanup

    private func clearOverlay() {
        arrowNode?.removeFromParent()
        arrowNode = nil
        spotlightNode?.removeFromParent()
        spotlightNode = nil
        clearMessage()
    }

    private func clearMessage() {
        messageNode?.removeFromParent()
        messageNode = nil
    }

    private func completeTutorial() {
        clearOverlay()
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
        UserProgressManager.shared.tutorialCompleted = true
    }

    // MARK: - Utility

    private func run(after delay: TimeInterval, action: @escaping () -> Void) {
        scene?.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run(action)
        ]))
    }

    private enum ArrowDirection {
        case up, down, left, right
    }
}

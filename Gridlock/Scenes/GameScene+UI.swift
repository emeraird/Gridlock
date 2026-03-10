import SpriteKit

// MARK: - In-Game UI & Game Over Touch Handling

extension GameScene {

    /// Handle touches that occur during the game over state.
    /// Called from the main touchesEnded in GameScene+Input.
    func handleGameOverTouches(at location: CGPoint) {
        guard gameState.phase == .gameOver else { return }

        if let container = childNode(withName: "gameOverContainer") {
            for child in container.children {
                guard let name = child.name else { continue }
                let childWorldPos = child.convert(CGPoint.zero, to: self)
                if location.distance(to: childWorldPos) < 60 {
                    HapticManager.shared.buttonTap()
                    AudioManager.shared.play(.buttonTap)

                    // Button press animation
                    child.run(SKAction.sequence([
                        SKAction.scale(to: 0.9, duration: 0.05),
                        SKAction.scale(to: 1.0, duration: 0.1)
                    ]))

                    handleGameOverButton(named: name)
                    return
                }
            }
        }
    }

    /// Update the high score display
    func updateHighScoreDisplay() {
        highScoreLabel.text = "best: \(gameState.scoreEngine.highScore)"
    }

    /// Show/hide combo indicator with pulse
    func updateComboDisplay() {
        let combo = gameState.scoreEngine.comboCount
        if combo >= 2 {
            comboLabel.text = "COMBO x\(min(combo, 5))"
            comboLabel.fontColor = theme.comboColor(for: combo)
            if comboLabel.alpha < 1 {
                comboLabel.run(SKAction.fadeIn(withDuration: 0.1))
            }
            comboLabel.removeAction(forKey: "comboPulse")
            comboLabel.pulseForever(minAlpha: 0.7, maxAlpha: 1.0, duration: 0.4)
        } else {
            comboLabel.run(SKAction.fadeOut(withDuration: 0.2))
            comboLabel.stopPulse()
        }
    }

    /// Transition the scene theme
    func applyTheme() {
        backgroundColor = theme.backgroundColor

        // Update score labels
        scoreLabel.fontColor = theme.scoreTextColor
        highScoreLabel.fontColor = theme.scoreTextColor.withAlphaComponent(0.6)

        // Regenerate grid background
        if let gridBg = gridNode.children.first(where: { $0.zPosition == 0 }) as? SKSpriteNode {
            let bgTexture = TextureGenerator.shared.gridBackgroundTexture(
                gridSize: gridSize, cellSize: cellSize,
                backgroundColor: theme.gridBackgroundColor,
                lineColor: theme.gridLineColor,
                cellColor: theme.cellEmptyColor
            )
            gridBg.texture = bgTexture
        }

        // Re-render blocks with new theme colors
        refreshGrid()
        refreshPieceTray()
        updatePowerUpBar()
    }
}

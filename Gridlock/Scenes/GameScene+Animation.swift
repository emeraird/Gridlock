import SpriteKit

// MARK: - Animations

extension GameScene {

    // MARK: - Line Clear Animation

    func animateLineClear(result: ClearResult) {
        let totalLines = result.totalLinesCleared
        let comboLevel = result.comboMultiplier

        // Flash cleared blocks white
        for pos in result.clearedPositions {
            guard let blockNode = blockNodes[pos.row][pos.col] else { continue }

            // White flash
            let flash = SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05),
                SKAction.wait(forDuration: 0.1)
            ])
            blockNode.run(flash)

            // Particle shatter
            let particleCount = min(4 + comboLevel, 8)
            spawnShatterParticles(
                at: blockNode.position,
                in: gridNode,
                count: particleCount,
                color: blockNode.color,
                comboLevel: comboLevel
            )

            // Remove block with slight delay
            blockNode.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.15),
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.1),
                    SKAction.scale(to: 0.3, duration: 0.1)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        // Ripple effect from cleared lines
        for row in result.clearedRows {
            let center = positionForCell(row: row, col: gridSize / 2)
            spawnRipple(at: center, in: gridNode, horizontal: true)
        }
        for col in result.clearedColumns {
            let center = positionForCell(row: gridSize / 2, col: col)
            spawnRipple(at: center, in: gridNode, horizontal: false)
        }

        // Screen shake (intensity based on lines cleared)
        let shakeAmplitude: CGFloat = totalLines >= 4 ? 3.0 : (totalLines >= 2 ? 1.5 : 0.5)
        let shakeDuration: TimeInterval = totalLines >= 4 ? 0.2 : 0.1
        gridNode.shake(amplitude: shakeAmplitude, duration: shakeDuration)

        // Haptic
        HapticManager.shared.lineClear()
        if comboLevel >= 2 {
            HapticManager.shared.comboHaptic(level: comboLevel)
        }

        // Audio
        AudioManager.shared.play(.clearLine)
        AudioManager.shared.duckMusic(duration: 0.3)
        if comboLevel >= 2 {
            AudioManager.shared.playComboSound(level: comboLevel)
        }

        // Combo visual intensity
        if comboLevel >= 3 {
            flashBackground(intensity: comboLevel)
        }
        if comboLevel >= 5 {
            spawnRainbowExplosion()
        }

        // Delayed grid refresh
        run(SKAction.wait(forDuration: 0.25)) { [weak self] in
            self?.refreshGrid()
        }
    }

    // MARK: - Particle Effects

    private func spawnShatterParticles(at position: CGPoint, in parent: SKNode, count: Int, color: UIColor, comboLevel: Int) {
        for _ in 0..<count {
            let particle = SKSpriteNode(color: comboLevel >= 4 ? .yellow : (color == .clear ? theme.particleColor : color),
                                         size: CGSize(width: 4, height: 4))
            particle.position = position
            particle.zPosition = 10

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...80) * (1.0 + CGFloat(comboLevel) * 0.2)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed

            parent.addChild(particle)

            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.scale(to: 0.2, duration: 0.4)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func spawnRipple(at position: CGPoint, in parent: SKNode, horizontal: Bool) {
        let ripple = SKShapeNode(circleOfRadius: 5)
        ripple.position = position
        ripple.strokeColor = theme.particleColor.withAlphaComponent(0.5)
        ripple.fillColor = .clear
        ripple.lineWidth = 2
        ripple.zPosition = 8
        parent.addChild(ripple)

        let targetSize: CGFloat = cellSize * CGFloat(gridSize)
        ripple.run(SKAction.sequence([
            SKAction.group([
                horizontal ?
                    SKAction.scaleX(to: targetSize / 10, y: 3, duration: 0.3) :
                    SKAction.scaleX(to: 3, y: targetSize / 10, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func flashBackground(intensity: Int) {
        let flashColor = theme.comboColor(for: intensity).withAlphaComponent(0.1)
        let flash = SKSpriteNode(color: flashColor, size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 0.5
        flash.alpha = 0
        addChild(flash)

        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.05),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }

    private func spawnRainbowExplosion() {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let colors: [UIColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple]

        for (i, color) in colors.enumerated() {
            let particle = SKSpriteNode(color: color, size: CGSize(width: 6, height: 6))
            particle.position = center
            particle.zPosition = 15

            let angle = CGFloat(i) / CGFloat(colors.count) * 2 * .pi
            let speed: CGFloat = 200

            addChild(particle)
            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * speed, y: sin(angle) * speed, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.scale(to: 3, duration: 0.3)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Reinforcement Messages

    func showReinforcementMessage(_ message: ReinforcementMessage, comboLevel: Int) {
        let label = SKLabelNode(text: message.rawValue)
        label.fontName = "SF Pro Display Heavy"
        label.fontSize = 32 + CGFloat(message.intensity) * 4
        label.fontColor = theme.comboColor(for: message.intensity)
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        label.zPosition = 80
        label.alpha = 0
        label.setScale(0.5)

        // Add subtle stroke/shadow
        let shadow = SKLabelNode(text: message.rawValue)
        shadow.fontName = label.fontName
        shadow.fontSize = label.fontSize
        shadow.fontColor = .black.withAlphaComponent(0.5)
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        label.addChild(shadow)

        addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.bounceIn(to: 1.0, duration: 0.2)
            ]),
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.moveBy(x: 0, y: 40, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    func showComboMessage(_ text: String, level: Int) {
        comboLabel.text = text
        comboLabel.fontColor = theme.comboColor(for: level)

        comboLabel.removeAllActions()
        comboLabel.alpha = 0
        comboLabel.setScale(0.5)

        comboLabel.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.bounceIn(to: 1.2, duration: 0.15)
            ]),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 0.6),
            SKAction.fadeOut(withDuration: 0.2)
        ]))
    }

    // MARK: - Score Popup

    func showScorePopup(points: Int, at position: CGPoint) {
        let label = SKLabelNode(text: "+\(points)")
        label.fontName = "SF Pro Display Bold"
        label.fontSize = 22
        label.fontColor = theme.scoreTextColor
        label.position = position
        label.zPosition = 70
        addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 60, duration: 0.8),
                SKAction.sequence([
                    SKAction.fadeIn(withDuration: 0.1),
                    SKAction.wait(forDuration: 0.4),
                    SKAction.fadeOut(withDuration: 0.3)
                ])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Power-Up Effects

    func animatePowerUpEarned(_ type: PowerUpType) {
        let icon = SKLabelNode(text: powerUpEmoji(type))
        icon.fontSize = 30
        icon.position = CGPoint(x: size.width / 2, y: size.height / 2)
        icon.zPosition = 60
        addChild(icon)

        let targetPos = powerUpBar.convert(.zero, to: self)

        icon.run(SKAction.sequence([
            SKAction.group([
                SKAction.bounceIn(to: 1.5, duration: 0.2),
                SKAction.fadeIn(withDuration: 0.1)
            ]),
            SKAction.wait(forDuration: 0.2),
            SKAction.group([
                SKAction.move(to: targetPos, duration: 0.3),
                SKAction.scale(to: 0.5, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))

        HapticManager.shared.powerUpEarned()
        AudioManager.shared.play(.powerUpEarn)
    }

    func animatePowerUpEffect(type: PowerUpType, affected: Set<GridPosition>) {
        switch type {
        case .bomb:
            // Explosion effect
            for pos in affected {
                let worldPos = positionForCell(row: pos.row, col: pos.col)
                spawnShatterParticles(at: worldPos, in: gridNode, count: 6, color: .orange, comboLevel: 3)
            }
            gridNode.shake(amplitude: 4, duration: 0.2)

        case .lineBlast:
            // Laser beam effect
            if let firstPos = affected.first {
                let isRow = affected.allSatisfy { $0.row == firstPos.row }
                let start = positionForCell(row: firstPos.row, col: isRow ? 0 : firstPos.col)
                let beam = SKSpriteNode(color: theme.uiAccentColor,
                                         size: isRow ? CGSize(width: cellSize * CGFloat(gridSize), height: 4) :
                                                       CGSize(width: 4, height: cellSize * CGFloat(gridSize)))
                beam.position = start
                beam.zPosition = 15
                beam.alpha = 0.8
                gridNode.addChild(beam)

                beam.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.fadeOut(withDuration: 0.3),
                        isRow ? SKAction.scaleY(to: 8, duration: 0.15) : SKAction.scaleX(to: 8, duration: 0.15)
                    ]),
                    SKAction.removeFromParent()
                ]))
            }

        case .undo:
            // Rewind visual
            let rewind = SKSpriteNode(color: theme.uiAccentColor.withAlphaComponent(0.2), size: size)
            rewind.position = CGPoint(x: size.width / 2, y: size.height / 2)
            rewind.zPosition = 50
            addChild(rewind)
            rewind.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))

        case .shuffle:
            // Dissolve and materialize
            for (index, _) in pieceTrays.enumerated() {
                let slot = pieceTrays[index]
                slot.children.filter { $0.name == "piecePreview" }.forEach { node in
                    node.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.fadeOut(withDuration: 0.2),
                            SKAction.scale(to: 0.1, duration: 0.2)
                        ]),
                        SKAction.removeFromParent()
                    ]))
                }
            }
            run(SKAction.wait(forDuration: 0.25)) { [weak self] in
                self?.refreshPieceTray()
            }
        }
    }

    // MARK: - Game Over Animation

    func animateGameOver() {
        HapticManager.shared.gameOver()
        AudioManager.shared.play(.gameOver)

        // Darken overlay
        let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 85
        overlay.alpha = 0
        overlay.name = "gameOverOverlay"
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.5))

        // Game Over container
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        container.zPosition = 90
        container.name = "gameOverContainer"
        addChild(container)

        // "GAME OVER" text
        let gameOverLabel = SKLabelNode(text: "GAME OVER")
        gameOverLabel.fontName = "SF Pro Display Heavy"
        gameOverLabel.fontSize = 36
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: 0, y: 80)
        container.addChild(gameOverLabel)

        // Score with count-up animation
        let scoreValueLabel = SKLabelNode(text: "0")
        scoreValueLabel.fontName = "SF Pro Display Bold"
        scoreValueLabel.fontSize = 48
        scoreValueLabel.fontColor = theme.uiAccentColor
        scoreValueLabel.position = CGPoint(x: 0, y: 20)
        container.addChild(scoreValueLabel)

        let finalScore = gameState.scoreEngine.currentScore
        let countUp = SKAction.countUp(from: 0, to: finalScore, duration: 1.0) { value in
            scoreValueLabel.text = "\(value)"
        }
        scoreValueLabel.run(countUp)

        // High score
        if gameState.isNewHighScore {
            run(SKAction.wait(forDuration: 1.0)) { [weak self] in
                self?.animateNewHighScore()
            }

            let newHighLabel = SKLabelNode(text: "NEW HIGH SCORE!")
            newHighLabel.fontName = "SF Pro Display Heavy"
            newHighLabel.fontSize = 20
            newHighLabel.fontColor = .yellow
            newHighLabel.position = CGPoint(x: 0, y: -20)
            newHighLabel.alpha = 0
            container.addChild(newHighLabel)

            newHighLabel.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.1),
                SKAction.fadeIn(withDuration: 0.3)
            ]))
        }

        // Buttons
        let buttonY: CGFloat = -80
        let buttonSpacing: CGFloat = 55

        let playAgainButton = createGameOverButton(text: "Play Again", name: "playAgainButton",
                                                    color: theme.buttonColor, y: buttonY)
        container.addChild(playAgainButton)

        // Watch ad to continue
        if AdManager.shared.canShowRewardedAd(placement: .continueAfterGameOver) {
            let continueButton = createGameOverButton(text: "Watch Ad to Continue", name: "continueAdButton",
                                                       color: UIColor(hex: "4CAF50"), y: buttonY - buttonSpacing)
            container.addChild(continueButton)
        }

        let menuButton = createGameOverButton(text: "Main Menu", name: "menuButton",
                                               color: UIColor.gray, y: buttonY - buttonSpacing * 2)
        container.addChild(menuButton)

        // Fade in container
        container.alpha = 0
        container.setScale(0.8)
        container.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.bounceIn(to: 1.0, duration: 0.3)
        ]))
    }

    private func createGameOverButton(text: String, name: String, color: UIColor, y: CGFloat) -> SKNode {
        let buttonNode = SKNode()
        buttonNode.name = name
        buttonNode.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 240, height: 44), cornerRadius: 12)
        bg.fillColor = color
        bg.strokeColor = .clear
        buttonNode.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "SF Pro Display Bold"
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        buttonNode.addChild(label)

        return buttonNode
    }

    // MARK: - New High Score

    func animateNewHighScore() {
        HapticManager.shared.newHighScore()
        AudioManager.shared.play(.highScore)

        // Confetti particles
        let colors: [UIColor] = [.red, .yellow, .green, .blue, .purple, .orange, .cyan]
        for _ in 0..<30 {
            let particle = SKSpriteNode(color: colors.randomElement()!, size: CGSize(width: 6, height: 6))
            particle.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 10)
            particle.zPosition = 95

            let endX = particle.position.x + CGFloat.random(in: -50...50)
            let endY = CGFloat.random(in: 0...size.height * 0.5)
            let duration = Double.random(in: 1.0...2.0)

            addChild(particle)
            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(to: CGPoint(x: endX, y: endY), duration: duration),
                    SKAction.rotate(byAngle: CGFloat.random(in: -4...4), duration: duration),
                    SKAction.sequence([
                        SKAction.wait(forDuration: duration * 0.7),
                        SKAction.fadeOut(withDuration: duration * 0.3)
                    ])
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Game Over Button Handling

    func handleGameOverButton(named name: String) {
        switch name {
        case "playAgainButton":
            dismissGameOver {
                self.gameState.startNewGame()
                self.refreshGrid()
                self.refreshPieceTray()
                self.updatePowerUpBar()
            }

        case "continueAdButton":
            AdManager.shared.showRewardedAd(placement: .continueAfterGameOver, from: nil) { [weak self] success in
                if success {
                    self?.dismissGameOver {
                        self?.gameState.continueAfterAd()
                        self?.refreshGrid()
                        self?.refreshPieceTray()
                    }
                }
            }

        case "menuButton":
            dismissGameOver {
                self.gameState.returnToMenu()
                // The SwiftUI container will handle the transition
                NotificationCenter.default.post(name: .returnToMenu, object: nil)
            }

        default:
            break
        }
    }

    private func dismissGameOver(completion: @escaping () -> Void) {
        let overlay = childNode(withName: "gameOverOverlay")
        let container = childNode(withName: "gameOverContainer")

        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        overlay?.run(SKAction.sequence([fadeOut, SKAction.removeFromParent()]))
        container?.run(SKAction.sequence([fadeOut, SKAction.removeFromParent()])) {
            completion()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let returnToMenu = Notification.Name("returnToMenu")
    static let showDailyChallenge = Notification.Name("showDailyChallenge")
}

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

        let targetPos = powerUpBar.convert(CGPoint.zero, to: self)

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

        // Show tooltip on first earn of this type
        let tooltipKey = "powerUpTooltipShown_\(type.rawValue)"
        if !UserDefaults.standard.bool(forKey: tooltipKey) {
            UserDefaults.standard.set(true, forKey: tooltipKey)
            showPowerUpTooltip(type)
        }
    }

    private func showPowerUpTooltip(_ type: PowerUpType) {
        let description: String
        switch type {
        case .bomb: description = "Bomb — Tap to destroy a 3×3 area!"
        case .lineBlast: description = "Line Blast — Clears an entire row or column!"
        case .undo: description = "Undo — Reverts your last move!"
        case .shuffle: description = "Shuffle — Get a fresh set of pieces!"
        }

        let container = SKNode()
        container.zPosition = 80
        container.position = CGPoint(x: size.width / 2, y: gridOrigin.y - 70)
        container.alpha = 0

        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 40), cornerRadius: 10)
        bg.fillColor = UIColor.black.withAlphaComponent(0.85)
        bg.strokeColor = theme.uiAccentColor.withAlphaComponent(0.6)
        bg.lineWidth = 1
        container.addChild(bg)

        let label = SKLabelNode(text: description)
        label.fontName = "SF Pro Display Semibold"
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        container.name = "powerUpTooltip"
        addChild(container)

        container.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 2.5),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
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

        // Clean up zone state
        zoneOverlayNode?.removeFromParent()
        zoneOverlayNode = nil
        zoneManager.onComboBreak()

        // Stop ghost competitors
        ghostManager.stopUpdating()

        // Darken overlay
        let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.8), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 85
        overlay.alpha = 0
        overlay.name = "gameOverOverlay"
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.5))

        // Game Over container
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2 + 120)
        container.zPosition = 90
        container.name = "gameOverContainer"
        addChild(container)

        var yPos: CGFloat = 0

        // "GAME OVER" text
        let gameOverLabel = SKLabelNode(text: "GAME OVER")
        gameOverLabel.fontName = "SF Pro Display Heavy"
        gameOverLabel.fontSize = 32
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: 0, y: yPos)
        container.addChild(gameOverLabel)
        yPos -= 55

        // Score with count-up animation
        let scoreValueLabel = SKLabelNode(text: "0")
        scoreValueLabel.fontName = "SF Pro Display Bold"
        scoreValueLabel.fontSize = 52
        scoreValueLabel.fontColor = theme.uiAccentColor
        scoreValueLabel.position = CGPoint(x: 0, y: yPos)
        container.addChild(scoreValueLabel)

        let finalScore = gameState.scoreEngine.currentScore
        let countUp = SKAction.countUp(from: 0, to: finalScore, duration: 1.0) { value in
            scoreValueLabel.text = "\(value)"
        }
        scoreValueLabel.run(countUp)
        yPos -= 30

        // High score badge
        if gameState.isNewHighScore {
            run(SKAction.wait(forDuration: 1.0)) { [weak self] in
                self?.animateNewHighScore()
            }

            let newHighLabel = SKLabelNode(text: "⭐ NEW HIGH SCORE! ⭐")
            newHighLabel.fontName = "SF Pro Display Heavy"
            newHighLabel.fontSize = 18
            newHighLabel.fontColor = .yellow
            newHighLabel.position = CGPoint(x: 0, y: yPos)
            newHighLabel.alpha = 0
            container.addChild(newHighLabel)
            newHighLabel.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.1),
                SKAction.fadeIn(withDuration: 0.3)
            ]))
            yPos -= 30
        } else {
            let bestLabel = SKLabelNode(text: "Best: \(gameState.scoreEngine.highScore)")
            bestLabel.fontName = "SF Pro Display"
            bestLabel.fontSize = 14
            bestLabel.fontColor = .white.withAlphaComponent(0.6)
            bestLabel.position = CGPoint(x: 0, y: yPos)
            container.addChild(bestLabel)
            yPos -= 25
        }

        // Stats row
        yPos -= 10
        let statsRow = SKNode()
        statsRow.position = CGPoint(x: 0, y: yPos)
        container.addChild(statsRow)

        let stats: [(String, String)] = [
            ("Lines", "\(gameState.scoreEngine.totalLinesCleared)"),
            ("Pieces", "\(gameState.scoreEngine.totalPiecesPlaced)"),
            ("Best Combo", "\(zoneManager.bestComboThisGame)x"),
            ("Time", formatTime(gameState.elapsedTime))
        ]

        let statSpacing: CGFloat = 72
        let startX = -statSpacing * CGFloat(stats.count - 1) / 2

        for (i, stat) in stats.enumerated() {
            let x = startX + CGFloat(i) * statSpacing

            let valueLabel = SKLabelNode(text: stat.1)
            valueLabel.fontName = "SF Pro Display Bold"
            valueLabel.fontSize = 16
            valueLabel.fontColor = .white
            valueLabel.position = CGPoint(x: x, y: 6)
            valueLabel.alpha = 0
            statsRow.addChild(valueLabel)

            let titleLabel = SKLabelNode(text: stat.0)
            titleLabel.fontName = "SF Pro Display"
            titleLabel.fontSize = 10
            titleLabel.fontColor = .white.withAlphaComponent(0.5)
            titleLabel.position = CGPoint(x: x, y: -8)
            titleLabel.alpha = 0
            statsRow.addChild(titleLabel)

            // Stagger fade in
            let delay = 1.2 + Double(i) * 0.1
            valueLabel.run(SKAction.sequence([SKAction.wait(forDuration: delay), SKAction.fadeIn(withDuration: 0.2)]))
            titleLabel.run(SKAction.sequence([SKAction.wait(forDuration: delay), SKAction.fadeIn(withDuration: 0.2)]))
        }
        yPos -= 40

        // Ghost standings
        let standings = ghostManager.finalStandings()
        if !standings.isEmpty {
            let standingsTitle = SKLabelNode(text: "STANDINGS")
            standingsTitle.fontName = "SF Pro Display Heavy"
            standingsTitle.fontSize = 12
            standingsTitle.fontColor = .white.withAlphaComponent(0.4)
            standingsTitle.position = CGPoint(x: 0, y: yPos)
            standingsTitle.alpha = 0
            container.addChild(standingsTitle)
            standingsTitle.run(SKAction.sequence([SKAction.wait(forDuration: 1.5), SKAction.fadeIn(withDuration: 0.2)]))
            yPos -= 22

            for (i, entry) in standings.prefix(3).enumerated() {
                let rankEmoji = i == 0 ? "🥇" : (i == 1 ? "🥈" : "🥉")
                let nameText = entry.isPlayer ? "You" : entry.name
                let highlight = entry.isPlayer

                let row = SKNode()
                row.position = CGPoint(x: 0, y: yPos)
                row.alpha = 0
                container.addChild(row)

                let rankLabel = SKLabelNode(text: "\(rankEmoji) \(entry.emoji) \(nameText)")
                rankLabel.fontName = highlight ? "SF Pro Display Bold" : "SF Pro Display"
                rankLabel.fontSize = 14
                rankLabel.fontColor = highlight ? theme.uiAccentColor : .white.withAlphaComponent(0.7)
                rankLabel.horizontalAlignmentMode = .left
                rankLabel.position = CGPoint(x: -120, y: 0)
                row.addChild(rankLabel)

                let scoreLabel = SKLabelNode(text: "\(entry.score)")
                scoreLabel.fontName = "SF Pro Display Bold"
                scoreLabel.fontSize = 14
                scoreLabel.fontColor = highlight ? theme.uiAccentColor : .white.withAlphaComponent(0.7)
                scoreLabel.horizontalAlignmentMode = .right
                scoreLabel.position = CGPoint(x: 120, y: 0)
                row.addChild(scoreLabel)

                let delay = 1.6 + Double(i) * 0.15
                row.run(SKAction.sequence([SKAction.wait(forDuration: delay), SKAction.fadeIn(withDuration: 0.2)]))
                yPos -= 22
            }
        }
        yPos -= 15

        // Record user progress stats
        UserProgressManager.shared.recordGameEnd(
            score: finalScore,
            linesCleared: gameState.scoreEngine.totalLinesCleared,
            blocksPlaced: gameState.scoreEngine.totalPiecesPlaced,
            maxCombo: zoneManager.bestComboThisGame,
            duration: gameState.elapsedTime
        )

        // Session tracking
        SessionManager.shared.onGameEnd(
            score: finalScore,
            linesCleared: gameState.scoreEngine.totalLinesCleared,
            bestCombo: zoneManager.bestComboThisGame
        )

        // Analytics
        AnalyticsManager.shared.logGameOver(
            score: finalScore,
            linesCleared: gameState.scoreEngine.totalLinesCleared,
            bestCombo: zoneManager.bestComboThisGame,
            timeElapsed: gameState.elapsedTime,
            isNewHigh: gameState.isNewHighScore
        )

        // Smart interstitial ad + optional upsell
        AdManager.shared.handlePostGameAd(from: nil) { [weak self] showedAd, shouldUpsell in
            guard let self = self else { return }
            if shouldUpsell {
                self.run(SKAction.wait(forDuration: 0.5)) {
                    self.showRemoveAdsUpsell()
                }
            }
        }

        // App review prompt (delayed, only after satisfying games)
        run(SKAction.wait(forDuration: 3.0)) {
            AppReviewManager.shared.requestReviewIfAppropriate(
                score: finalScore,
                isNewHighScore: self.gameState.isNewHighScore
            )
        }

        // Request notification permission after N games
        AppDelegate.requestNotificationPermissionIfNeeded()

        // Session nudge message
        if let nudge = SessionManager.shared.gameOverNudge {
            let nudgeLabel = SKLabelNode(text: nudge)
            nudgeLabel.fontName = "SF Pro Display Medium"
            nudgeLabel.fontSize = 12
            nudgeLabel.fontColor = .white.withAlphaComponent(0.7)
            nudgeLabel.position = CGPoint(x: 0, y: yPos)
            nudgeLabel.alpha = 0
            container.addChild(nudgeLabel)
            nudgeLabel.run(SKAction.sequence([SKAction.wait(forDuration: 1.8), SKAction.fadeIn(withDuration: 0.3)]))
            yPos -= 20
        }

        // Buttons (appear after stats)
        let buttonDelay: TimeInterval = 2.0

        // Watch ad to continue (most prominent if available)
        if AdManager.shared.canShowRewardedAd(placement: .continueAfterGameOver) {
            let continueButton = createGameOverButton(text: "▶ Continue (Watch Ad)", name: "continueAdButton",
                                                       color: UIColor(hex: "4CAF50"), y: yPos)
            continueButton.alpha = 0
            container.addChild(continueButton)
            continueButton.run(SKAction.sequence([SKAction.wait(forDuration: buttonDelay), SKAction.fadeIn(withDuration: 0.2)]))
            yPos -= 50
        }

        let playLabel = SessionManager.shared.playAgainLabel
        let playAgainButton = createGameOverButton(text: playLabel, name: "playAgainButton",
                                                    color: theme.buttonColor, y: yPos)
        playAgainButton.alpha = 0
        container.addChild(playAgainButton)
        playAgainButton.run(SKAction.sequence([SKAction.wait(forDuration: buttonDelay + 0.1), SKAction.fadeIn(withDuration: 0.2)]))
        yPos -= 50

        let shareButton = createGameOverButton(text: "Share Score", name: "shareButton",
                                                color: UIColor(hex: "1DA1F2"), y: yPos)
        shareButton.alpha = 0
        container.addChild(shareButton)
        shareButton.run(SKAction.sequence([SKAction.wait(forDuration: buttonDelay + 0.2), SKAction.fadeIn(withDuration: 0.2)]))
        yPos -= 50

        let menuButton = createGameOverButton(text: "Main Menu", name: "menuButton",
                                               color: UIColor.gray.withAlphaComponent(0.6), y: yPos)
        menuButton.alpha = 0
        container.addChild(menuButton)
        menuButton.run(SKAction.sequence([SKAction.wait(forDuration: buttonDelay + 0.3), SKAction.fadeIn(withDuration: 0.2)]))

        // Fade in container
        container.alpha = 0
        container.setScale(0.8)
        container.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.bounceIn(to: 1.0, duration: 0.3)
        ]))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func createGameOverButton(text: String, name: String, color: UIColor, y: CGFloat) -> SKNode {
        let buttonNode = SKNode()
        buttonNode.name = name
        buttonNode.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 260, height: 44), cornerRadius: 12)
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
        AnalyticsManager.shared.log(.newHighScore, parameters: ["score": gameState.scoreEngine.currentScore])

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
            AnalyticsManager.shared.log(.playAgain)
            dismissGameOver {
                // Reset zone state
                self.zoneManager.resetForNewGame()
                self.zoneOverlayNode?.removeFromParent()
                self.zoneOverlayNode = nil

                // Reset milestones
                self.milestoneManager.resetForNewGame()

                // Reset ghost competitors
                self.ghostManager.stopUpdating()
                self.ghostManager.generateGhosts(playerHighScore: self.gameState.scoreEngine.highScore)
                self.ghostManager.startUpdating()

                self.gameState.clearSavedGame()
                self.gameState.startNewGame()
                self.gameState.powerUpSystem.resetPointTracking()
                SessionManager.shared.onGameStart()
                AdManager.shared.onGameStart()
                NotificationScheduler.onGamePlayed()
                self.refreshGrid()
                self.refreshPieceTray()
                self.updatePowerUpBar()
                self.updateGhostTicker()

                // Mercy mode for struggling players
                if SessionManager.shared.mercyBonusPieces {
                    self.gameState.pieceGenerator.isTutorialMode = true
                    self.run(SKAction.wait(forDuration: 0.5)) { [weak self] in
                        self?.gameState.pieceGenerator.isTutorialMode = false
                    }
                }
            }

        case "continueAdButton":
            AnalyticsManager.shared.log(.gameOverContinue)
            AdManager.shared.showRewardedAd(placement: .continueAfterGameOver, from: nil) { [weak self] success in
                if success {
                    self?.dismissGameOver {
                        self?.gameState.continueAfterAd()
                        self?.refreshGrid()
                        self?.refreshPieceTray()
                    }
                }
            }

        case "shareButton":
            shareScore()

        case "menuButton":
            dismissGameOver {
                self.gameState.returnToMenu()
                NotificationCenter.default.post(name: .returnToMenu, object: nil)
            }

        default:
            break
        }
    }

    private func shareScore() {
        let result = ShareCardGenerator.GameResult(
            score: gameState.scoreEngine.currentScore,
            linesCleared: gameState.scoreEngine.totalLinesCleared,
            bestCombo: zoneManager.bestComboThisGame,
            timeElapsed: gameState.elapsedTime,
            isNewHighScore: gameState.isNewHighScore,
            rank: ghostManager.playerRank
        )

        ShareCardGenerator.shared.shareGameResult(result, from: nil)
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

    // MARK: - Daily Reward Popup

    func showDailyRewardPopup() {
        guard DailyRewardManager.shared.hasUncollectedReward,
              let reward = DailyRewardManager.shared.todayReward else { return }

        let popup = SKNode()
        popup.position = CGPoint(x: size.width / 2, y: size.height / 2)
        popup.zPosition = 95
        popup.name = "dailyRewardPopup"
        popup.alpha = 0
        popup.setScale(0.5)

        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: size)
        dim.position = .zero
        dim.zPosition = -1
        popup.addChild(dim)

        let card = SKShapeNode(rectOf: CGSize(width: 280, height: 240), cornerRadius: 20)
        card.fillColor = UIColor(white: 0.12, alpha: 1.0)
        card.strokeColor = UIColor.orange.withAlphaComponent(0.5)
        card.lineWidth = 2
        card.glowWidth = 6
        popup.addChild(card)

        let titleLabel = SKLabelNode(text: "Daily Reward")
        titleLabel.fontName = "SF Pro Display Heavy"
        titleLabel.fontSize = 22
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 80)
        popup.addChild(titleLabel)

        let emojiLabel = SKLabelNode(text: reward.emoji)
        emojiLabel.fontSize = 50
        emojiLabel.position = CGPoint(x: 0, y: 25)
        popup.addChild(emojiLabel)

        let rewardTitle = SKLabelNode(text: reward.title)
        rewardTitle.fontName = "SF Pro Display Bold"
        rewardTitle.fontSize = 18
        rewardTitle.fontColor = .orange
        rewardTitle.position = CGPoint(x: 0, y: -15)
        popup.addChild(rewardTitle)

        let descLabel = SKLabelNode(text: reward.bonusDescription)
        descLabel.fontName = "SF Pro Display Semibold"
        descLabel.fontSize = 14
        descLabel.fontColor = UIColor.green
        descLabel.position = CGPoint(x: 0, y: -40)
        popup.addChild(descLabel)

        let streakText = DailyRewardManager.shared.streakInfo
        if !streakText.isEmpty {
            let streakLabel = SKLabelNode(text: streakText)
            streakLabel.fontName = "SF Pro Display Medium"
            streakLabel.fontSize = 12
            streakLabel.fontColor = .white.withAlphaComponent(0.6)
            streakLabel.position = CGPoint(x: 0, y: -60)
            popup.addChild(streakLabel)
        }

        let collectBtn = SKNode()
        collectBtn.name = "collectDailyReward"
        collectBtn.position = CGPoint(x: 0, y: -85)

        let btnBg = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 12)
        btnBg.fillColor = UIColor.orange
        btnBg.strokeColor = .clear
        collectBtn.addChild(btnBg)

        let btnLabel = SKLabelNode(text: "Collect!")
        btnLabel.fontName = "SF Pro Display Bold"
        btnLabel.fontSize = 18
        btnLabel.fontColor = .white
        btnLabel.verticalAlignmentMode = .center
        collectBtn.addChild(btnLabel)

        popup.addChild(collectBtn)

        // "Double It!" rewarded ad button
        if AdManager.shared.canShowRewardedAd(placement: .doubleDailyReward) {
            let doubleBtn = SKNode()
            doubleBtn.name = "doubleDailyReward"
            doubleBtn.position = CGPoint(x: 0, y: -135)

            let dblBg = SKShapeNode(rectOf: CGSize(width: 200, height: 36), cornerRadius: 10)
            dblBg.fillColor = UIColor(hex: "4CAF50")
            dblBg.strokeColor = .clear
            doubleBtn.addChild(dblBg)

            let dblLabel = SKLabelNode(text: "▶ Double It! (Watch Ad)")
            dblLabel.fontName = "SF Pro Display Bold"
            dblLabel.fontSize = 13
            dblLabel.fontColor = .white
            dblLabel.verticalAlignmentMode = .center
            doubleBtn.addChild(dblLabel)

            popup.addChild(doubleBtn)
        }

        addChild(popup)

        popup.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.bounceIn(to: 1.0, duration: 0.3)
        ]))
    }

    func collectDailyReward() {
        guard let reward = DailyRewardManager.shared.collectReward(powerUpSystem: gameState.powerUpSystem) else { return }

        if let popup = childNode(withName: "dailyRewardPopup") {
            popup.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.scale(to: 1.1, duration: 0.2)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        for (type, _) in reward.powerUps {
            run(SKAction.wait(forDuration: 0.3)) { [weak self] in
                self?.animatePowerUpEarned(type)
            }
        }

        updatePowerUpBar()
        HapticManager.shared.dailyRewardCollect()
        AudioManager.shared.play(.dailyReward)
        AnalyticsManager.shared.log(.dailyRewardCollected)
    }

    func doubleDailyReward() {
        AdManager.shared.showRewardedAd(placement: .doubleDailyReward, from: nil) { [weak self] success in
            guard let self = self, success else { return }

            // Collect reward (normal)
            guard let reward = DailyRewardManager.shared.collectReward(powerUpSystem: self.gameState.powerUpSystem) else { return }

            // Award bonus duplicate set
            for (type, count) in reward.powerUps {
                for _ in 0..<count {
                    self.gameState.powerUpSystem.earn(type, reason: "daily reward double bonus")
                }
            }

            if let popup = self.childNode(withName: "dailyRewardPopup") {
                popup.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.fadeOut(withDuration: 0.2),
                        SKAction.scale(to: 1.1, duration: 0.2)
                    ]),
                    SKAction.removeFromParent()
                ]))
            }

            AnalyticsManager.shared.log(.dailyRewardDoubled)

            // Show "Doubled!" label
            let doubledLabel = SKLabelNode(text: "DOUBLED! 🎉")
            doubledLabel.fontName = "SF Pro Display Heavy"
            doubledLabel.fontSize = 28
            doubledLabel.fontColor = UIColor(hex: "4CAF50")
            doubledLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            doubledLabel.zPosition = 96
            doubledLabel.alpha = 0
            doubledLabel.setScale(0.5)
            self.addChild(doubledLabel)

            doubledLabel.run(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.15),
                    SKAction.bounceIn(to: 1.0, duration: 0.25)
                ]),
                SKAction.wait(forDuration: 0.8),
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.moveBy(x: 0, y: 40, duration: 0.3)
                ]),
                SKAction.removeFromParent()
            ]))

            self.updatePowerUpBar()
            HapticManager.shared.dailyRewardCollect()
            AudioManager.shared.play(.dailyReward)
        }
    }

    // MARK: - Remove Ads Upsell

    func showRemoveAdsUpsell() {
        let popup = SKNode()
        popup.position = CGPoint(x: size.width / 2, y: size.height / 2)
        popup.zPosition = 96
        popup.name = "removeAdsPopup"
        popup.alpha = 0
        popup.setScale(0.5)

        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.6), size: size)
        dim.position = .zero
        dim.zPosition = -1
        popup.addChild(dim)

        let card = SKShapeNode(rectOf: CGSize(width: 290, height: 200), cornerRadius: 20)
        card.fillColor = UIColor(white: 0.12, alpha: 1.0)
        card.strokeColor = theme.uiAccentColor.withAlphaComponent(0.5)
        card.lineWidth = 2
        card.glowWidth = 4
        popup.addChild(card)

        // Title
        let titleLabel = SKLabelNode(text: "Tired of Ads?")
        titleLabel.fontName = "SF Pro Display Heavy"
        titleLabel.fontSize = 22
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 60)
        popup.addChild(titleLabel)

        // Benefit text
        let benefit1 = SKLabelNode(text: "No more interruptions")
        benefit1.fontName = "SF Pro Display Medium"
        benefit1.fontSize = 14
        benefit1.fontColor = .white.withAlphaComponent(0.8)
        benefit1.position = CGPoint(x: 0, y: 28)
        popup.addChild(benefit1)

        let benefit2 = SKLabelNode(text: "Support the developer")
        benefit2.fontName = "SF Pro Display Medium"
        benefit2.fontSize = 14
        benefit2.fontColor = .white.withAlphaComponent(0.8)
        benefit2.position = CGPoint(x: 0, y: 8)
        popup.addChild(benefit2)

        // CTA button
        let ctaBtn = SKNode()
        ctaBtn.name = "removeAdsCTA"
        ctaBtn.position = CGPoint(x: 0, y: -35)

        let ctaBg = SKShapeNode(rectOf: CGSize(width: 220, height: 44), cornerRadius: 12)
        ctaBg.fillColor = theme.uiAccentColor
        ctaBg.strokeColor = .clear
        ctaBtn.addChild(ctaBg)

        let ctaLabel = SKLabelNode(text: "Remove Ads")
        ctaLabel.fontName = "SF Pro Display Bold"
        ctaLabel.fontSize = 16
        ctaLabel.fontColor = .white
        ctaLabel.verticalAlignmentMode = .center
        ctaBtn.addChild(ctaLabel)
        popup.addChild(ctaBtn)

        // Dismiss
        let dismissLabel = SKLabelNode(text: "No thanks")
        dismissLabel.fontName = "SF Pro Display"
        dismissLabel.fontSize = 13
        dismissLabel.fontColor = .white.withAlphaComponent(0.5)
        dismissLabel.position = CGPoint(x: 0, y: -72)
        dismissLabel.name = "dismissUpsell"
        popup.addChild(dismissLabel)

        addChild(popup)

        popup.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.bounceIn(to: 1.0, duration: 0.3)
        ]))

        HapticManager.shared.buttonTap()
    }

    func dismissRemoveAdsPopup() {
        if let popup = childNode(withName: "removeAdsPopup") {
            popup.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Watch Ad for Power-Up

    func showWatchAdForPowerUp() {
        guard MonetizationConfig.watchAdForPowerUpEnabled,
              AdManager.shared.canShowRewardedAd(placement: .freePowerUp) else { return }

        AdManager.shared.showRewardedAd(placement: .freePowerUp, from: nil) { [weak self] success in
            guard let self = self, success else { return }

            // Award a random power-up
            let types = PowerUpType.allCases
            let type = types.randomElement() ?? .bomb
            self.gameState.powerUpSystem.earn(type, reason: "watched ad")
            self.animatePowerUpEarned(type)
            self.updatePowerUpBar()
        }
    }

    // MARK: - Milestone Celebration

    func animateMilestone(_ event: MilestoneEvent) {
        let milestone = event.milestone

        // Celebration container
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2 + 80)
        container.zPosition = 88
        container.alpha = 0
        container.setScale(0.3)
        container.name = "milestoneContainer"
        addChild(container)

        // Background card
        let cardWidth: CGFloat = 260
        let cardHeight: CGFloat = event.reward.description.isEmpty ? 70 : 90
        let card = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 16)
        card.fillColor = UIColor.black.withAlphaComponent(0.85)
        card.strokeColor = UIColor.orange.withAlphaComponent(0.7)
        card.lineWidth = 2
        card.glowWidth = 4
        container.addChild(card)

        // Emoji
        let emojiLabel = SKLabelNode(text: milestone.emoji)
        emojiLabel.fontSize = 28
        emojiLabel.position = CGPoint(x: -cardWidth / 2 + 30, y: -2)
        emojiLabel.verticalAlignmentMode = .center
        container.addChild(emojiLabel)

        // Title
        let titleLabel = SKLabelNode(text: milestone.title)
        titleLabel.fontName = "SF Pro Display Heavy"
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -cardWidth / 2 + 55, y: event.reward.description.isEmpty ? 0 : 10)
        container.addChild(titleLabel)

        // Score threshold
        let thresholdLabel = SKLabelNode(text: "\(milestone.scoreThreshold) pts")
        thresholdLabel.fontName = "SF Pro Display Bold"
        thresholdLabel.fontSize = 11
        thresholdLabel.fontColor = .orange
        thresholdLabel.horizontalAlignmentMode = .right
        thresholdLabel.verticalAlignmentMode = .center
        thresholdLabel.position = CGPoint(x: cardWidth / 2 - 15, y: event.reward.description.isEmpty ? 0 : 10)
        container.addChild(thresholdLabel)

        // Reward description
        if !event.reward.description.isEmpty {
            let rewardLabel = SKLabelNode(text: "🎁 \(event.reward.description)")
            rewardLabel.fontName = "SF Pro Display Semibold"
            rewardLabel.fontSize = 12
            rewardLabel.fontColor = UIColor.green
            rewardLabel.horizontalAlignmentMode = .center
            rewardLabel.verticalAlignmentMode = .center
            rewardLabel.position = CGPoint(x: 10, y: -18)
            container.addChild(rewardLabel)
        }

        // First-time badge
        if event.isFirstTime {
            let newBadge = SKLabelNode(text: "NEW!")
            newBadge.fontName = "SF Pro Display Heavy"
            newBadge.fontSize = 10
            newBadge.fontColor = .yellow
            newBadge.position = CGPoint(x: cardWidth / 2 - 20, y: cardHeight / 2 - 8)
            container.addChild(newBadge)
        }

        // Animate in
        container.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.15),
                SKAction.bounceIn(to: 1.0, duration: 0.25)
            ]),
            SKAction.wait(forDuration: 1.8),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.moveBy(x: 0, y: 40, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))

        // Celebration particles
        spawnMilestoneParticles()

        // Haptic + audio + analytics
        HapticManager.shared.milestoneCelebration()
        AudioManager.shared.play(.milestone)
        AnalyticsManager.shared.logMilestone(
            name: milestone.title,
            score: milestone.scoreThreshold,
            isFirstTime: event.isFirstTime
        )
    }

    private func spawnMilestoneParticles() {
        let colors: [UIColor] = [.orange, .yellow, .white, .cyan]
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + 80)

        for _ in 0..<16 {
            let particle = SKSpriteNode(
                color: colors.randomElement()!,
                size: CGSize(width: 5, height: 5)
            )
            particle.position = center
            particle.zPosition = 89
            addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 60...140)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed

            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.scale(to: 0.3, duration: 0.5)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Near-Death Warning

    func checkNearDeathState() {
        let fillPct = BoardAnalyzer.fillPercentage(grid: gameState.grid)
        let dangerLevel = BoardAnalyzer.boardDangerLevel(grid: gameState.grid, pieces: gameState.availablePieces.compactMap { $0 })

        if dangerLevel >= 0.8 || fillPct >= 0.85 {
            showNearDeathWarning()
        } else {
            hideNearDeathWarning()
        }
    }

    private func showNearDeathWarning() {
        guard childNode(withName: "nearDeathOverlay") == nil else { return }

        // Red vignette pulse
        let overlay = SKSpriteNode(color: UIColor.red.withAlphaComponent(0.05), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 0.6
        overlay.name = "nearDeathOverlay"
        overlay.alpha = 0
        addChild(overlay)

        overlay.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 0.6),
            SKAction.fadeAlpha(to: 0.0, duration: 0.6)
        ])), withKey: "nearDeathPulse")

        HapticManager.shared.nearDeathSave()
        AudioManager.shared.play(.nearDeath)
    }

    func hideNearDeathWarning() {
        if let overlay = childNode(withName: "nearDeathOverlay") {
            overlay.removeAction(forKey: "nearDeathPulse")
            overlay.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Zone State Visuals

    func enterZoneMode() {
        guard zoneOverlayNode == nil else { return }

        let overlay = SKNode()
        overlay.name = "zoneOverlay"
        overlay.zPosition = 0.8
        addChild(overlay)
        zoneOverlayNode = overlay

        // Vignette overlay (darkened edges, bright center)
        let vignette = SKSpriteNode(color: .clear, size: size)
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.name = "zoneVignette"

        let vignetteColor = UIColor(red: 1.0, green: 0.3, blue: 0.0, alpha: 0.08)
        vignette.color = vignetteColor
        vignette.colorBlendFactor = 1.0
        vignette.alpha = 0
        overlay.addChild(vignette)

        vignette.run(SKAction.fadeAlpha(to: 1.0, duration: 0.3))

        // Grid border glow
        let totalGridSize = cellSize * CGFloat(gridSize)
        let glowBorder = SKShapeNode(rectOf: CGSize(width: totalGridSize + 8, height: totalGridSize + 8), cornerRadius: 6)
        glowBorder.position = CGPoint(
            x: gridOrigin.x + totalGridSize / 2,
            y: gridOrigin.y + totalGridSize / 2
        )
        glowBorder.strokeColor = UIColor.orange.withAlphaComponent(0.8)
        glowBorder.lineWidth = 3
        glowBorder.fillColor = .clear
        glowBorder.name = "zoneGlow"
        glowBorder.glowWidth = 8
        overlay.addChild(glowBorder)

        // Pulsing glow animation
        glowBorder.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])))

        // "🔥 ZONE!" banner
        showZoneBanner()

        // Zone ambient particles
        startZoneParticles()
    }

    private func showZoneBanner() {
        let banner = SKLabelNode(text: "🔥 ZONE!")
        banner.fontName = "SF Pro Display Heavy"
        banner.fontSize = 44
        banner.fontColor = .orange
        banner.position = CGPoint(x: size.width / 2, y: size.height / 2 + 60)
        banner.zPosition = 85
        banner.alpha = 0
        banner.setScale(0.3)
        banner.name = "zoneBanner"

        let shadow = SKLabelNode(text: "🔥 ZONE!")
        shadow.fontName = banner.fontName
        shadow.fontSize = banner.fontSize
        shadow.fontColor = .black.withAlphaComponent(0.6)
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = -1
        banner.addChild(shadow)

        addChild(banner)

        banner.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.15),
                SKAction.bounceIn(to: 1.3, duration: 0.25)
            ]),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 0.8),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.moveBy(x: 0, y: 50, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))

        HapticManager.shared.zoneEntry()
        AudioManager.shared.play(.zoneEnter)
        AudioManager.shared.duckMusic(duration: 0.5)
        AnalyticsManager.shared.log(.zoneEntered)
    }

    private func startZoneParticles() {
        guard let overlay = zoneOverlayNode else { return }

        let emitter = SKNode()
        emitter.name = "zoneEmitter"
        overlay.addChild(emitter)

        // Spawn fire-like particles along grid edges
        let spawnAction = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let intensity = self.zoneManager.zoneIntensity
                let particleCount = max(1, Int(intensity * 3))

                for _ in 0..<particleCount {
                    let particle = SKSpriteNode(
                        color: [UIColor.orange, .yellow, .red].randomElement()!,
                        size: CGSize(width: 4, height: 4)
                    )

                    let totalGridSize = self.cellSize * CGFloat(self.gridSize)
                    let side = Int.random(in: 0...3)
                    switch side {
                    case 0: // bottom
                        particle.position = CGPoint(
                            x: self.gridOrigin.x + CGFloat.random(in: 0...totalGridSize),
                            y: self.gridOrigin.y - 4
                        )
                    case 1: // top
                        particle.position = CGPoint(
                            x: self.gridOrigin.x + CGFloat.random(in: 0...totalGridSize),
                            y: self.gridOrigin.y + totalGridSize + 4
                        )
                    case 2: // left
                        particle.position = CGPoint(
                            x: self.gridOrigin.x - 4,
                            y: self.gridOrigin.y + CGFloat.random(in: 0...totalGridSize)
                        )
                    default: // right
                        particle.position = CGPoint(
                            x: self.gridOrigin.x + totalGridSize + 4,
                            y: self.gridOrigin.y + CGFloat.random(in: 0...totalGridSize)
                        )
                    }

                    particle.zPosition = 1
                    particle.alpha = 0.8
                    emitter.addChild(particle)

                    let dx = CGFloat.random(in: -20...20)
                    let dy = CGFloat.random(in: 20...60)
                    particle.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.moveBy(x: dx, y: dy, duration: 0.6),
                            SKAction.fadeOut(withDuration: 0.6),
                            SKAction.scale(to: 0.2, duration: 0.6)
                        ]),
                        SKAction.removeFromParent()
                    ]))
                }
            },
            SKAction.wait(forDuration: 0.2)
        ]))
        emitter.run(spawnAction)
    }

    func updateZoneIntensity() {
        guard zoneManager.isInZone, let overlay = zoneOverlayNode else { return }

        let intensity = zoneManager.zoneIntensity

        // Update vignette opacity based on intensity
        if let vignette = overlay.childNode(withName: "zoneVignette") as? SKSpriteNode {
            let alpha = 0.05 + intensity * 0.1
            vignette.alpha = CGFloat(alpha)
        }

        // Update glow border color intensity
        if let glow = overlay.childNode(withName: "zoneGlow") as? SKShapeNode {
            let glowWidth = 6 + intensity * 10
            glow.glowWidth = CGFloat(glowWidth)
        }
    }

    func exitZoneMode() {
        guard let overlay = zoneOverlayNode else { return }

        // Zone exit shatter effect
        let shatterLabel = SKLabelNode(text: "ZONE LOST")
        shatterLabel.fontName = "SF Pro Display Heavy"
        shatterLabel.fontSize = 28
        shatterLabel.fontColor = UIColor.red.withAlphaComponent(0.7)
        shatterLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        shatterLabel.zPosition = 85
        shatterLabel.alpha = 0
        addChild(shatterLabel)

        shatterLabel.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.1),
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.moveBy(x: 0, y: 30, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))

        // Fade out zone overlay
        overlay.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.removeFromParent()
        ]))
        zoneOverlayNode = nil

        HapticManager.shared.zoneExit()
        AudioManager.shared.play(.zoneExit)
    }

    func showZoneComboMessage() {
        guard let message = zoneManager.comboMessage else { return }
        let level = zoneManager.comboLevel

        // Enhanced combo message during zone
        let label = SKLabelNode(text: message)
        label.fontName = "SF Pro Display Heavy"
        label.fontSize = level >= 4 ? 36 : 28
        label.fontColor = level >= 7 ? .yellow : (level >= 4 ? .orange : theme.comboColor(for: level))
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
        label.zPosition = 82
        label.alpha = 0
        label.setScale(0.3)

        addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.bounceIn(to: 1.2, duration: 0.2)
            ]),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 0.6),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.moveBy(x: 0, y: 50, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))

        // Record indicators
        if zoneManager.newComboRecord {
            showComboRecordBadge()
        } else if zoneManager.tiedBestCombo {
            showComboTiedBadge()
        }
    }

    private func showComboRecordBadge() {
        let badge = SKLabelNode(text: "⭐ NEW RECORD!")
        badge.fontName = "SF Pro Display Heavy"
        badge.fontSize = 16
        badge.fontColor = .yellow
        badge.position = CGPoint(x: size.width / 2, y: size.height / 2 - 5)
        badge.zPosition = 83
        badge.alpha = 0
        addChild(badge)

        badge.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }

    private func showComboTiedBadge() {
        let badge = SKLabelNode(text: "Tied Best!")
        badge.fontName = "SF Pro Display Bold"
        badge.fontSize = 14
        badge.fontColor = .white.withAlphaComponent(0.7)
        badge.position = CGPoint(x: size.width / 2, y: size.height / 2 - 5)
        badge.zPosition = 83
        badge.alpha = 0
        addChild(badge)

        badge.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 0.8),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let returnToMenu = Notification.Name("returnToMenu")
    static let showDailyChallenge = Notification.Name("showDailyChallenge")
    static let shareScore = Notification.Name("shareScore")
    static let saveGameState = Notification.Name("saveGameState")
}

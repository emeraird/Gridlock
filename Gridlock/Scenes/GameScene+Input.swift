import SpriteKit
import os.log

// MARK: - Touch Handling & Drag-and-Drop

extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Remove ads popup: handle taps
        if let upsellPopup = childNode(withName: "removeAdsPopup") {
            // Check CTA button
            if let ctaBtn = upsellPopup.childNode(withName: "removeAdsCTA") {
                let btnPos = ctaBtn.convert(CGPoint.zero, to: self)
                if location.distance(to: btnPos) < 60 {
                    HapticManager.shared.buttonTap()
                    AnalyticsManager.shared.log(.removeAdsUpsellTapped)
                    dismissRemoveAdsPopup()
                    // Trigger IAP purchase flow
                    Task {
                        if let product = IAPManager.shared.product(for: MonetizationConfig.ProductID.removeAdsMonthly) {
                            _ = try? await IAPManager.shared.purchase(product)
                        }
                    }
                    return
                }
            }
            // Dismiss button or tap outside
            HapticManager.shared.buttonTap()
            dismissRemoveAdsPopup()
            return
        }

        // Daily reward popup: handle collect tap
        if let popup = childNode(withName: "dailyRewardPopup") {
            // Check "Double It!" button first
            if let doubleBtn = popup.childNode(withName: "doubleDailyReward") {
                let btnPos = doubleBtn.convert(CGPoint.zero, to: self)
                if location.distance(to: btnPos) < 60 {
                    HapticManager.shared.buttonTap()
                    doubleDailyReward()
                    return
                }
            }
            // Check if tapping the collect button
            if let collectBtn = popup.childNode(withName: "collectDailyReward") {
                let btnPos = collectBtn.convert(CGPoint.zero, to: self)
                if location.distance(to: btnPos) < 60 {
                    HapticManager.shared.buttonTap()
                    collectDailyReward()
                    return
                }
            }
            // Tap outside dismisses
            DailyRewardManager.shared.dismissPopup()
            popup.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
            return
        }

        // Game over state: handle button taps
        if gameState.phase == .gameOver {
            handleGameOverTouches(at: location)
            return
        }

        // Paused: tap anywhere to resume
        if gameState.phase == .paused {
            handlePauseButtonTap()
            return
        }

        // Check for pause button
        if pauseButton.contains(location) {
            handlePauseButtonTap()
            return
        }

        // Check power-up mode taps
        if case .powerUpMode(let type) = gameState.phase {
            handlePowerUpTap(type: type, at: location)
            return
        }

        // Check power-up bar taps
        if let powerUpNode = powerUpBar.children.first(where: { node in
            let nodePos = node.convert(CGPoint.zero, to: self)
            return location.distance(to: nodePos) < 30
        }), let name = powerUpNode.name, name.hasPrefix("powerUp_") {
            let typeStr = String(name.dropFirst("powerUp_".count))
            if let type = PowerUpType(rawValue: typeStr) {
                if gameState.powerUpSystem.canUse(type) {
                    HapticManager.shared.buttonTap()
                    AudioManager.shared.play(.buttonTap)
                    gameState.enterPowerUpMode(type)
                    showPowerUpModeIndicator(type)
                    return
                } else if AdManager.shared.canShowRewardedAd(placement: .freePowerUp) {
                    // Empty slot with ad available — offer free power-up
                    HapticManager.shared.buttonTap()
                    showWatchAdForPowerUp()
                    return
                }
            }
        }

        guard gameState.phase == .playing || gameState.phase == .dailyChallenge else { return }

        // Check for piece tray touch
        for (index, slot) in pieceTrays.enumerated() {
            guard (gameState.availablePieces[safe: index] ?? nil) != nil else { continue }
            guard gameState.availablePieces[index] != nil else { continue }

            let slotLocation = touch.location(in: slot)
            if slot.children.contains(where: {
                $0.name == "piecePreview" && $0.calculateAccumulatedFrame().contains(slotLocation)
            }) || slot.calculateAccumulatedFrame().contains(location) {
                startDragging(pieceIndex: index, from: location)
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let draggedNode = draggedPieceNode,
              let pieceIndex = draggedPieceIndex,
              let piece = gameState.availablePieces[pieceIndex] else { return }

        let location = touch.location(in: self)

        // Move dragged piece (offset above finger)
        draggedNode.position = CGPoint(x: location.x, y: location.y + cellSize * 2)

        // Calculate grid position for ghost preview
        let pieceLocation = CGPoint(x: draggedNode.position.x, y: draggedNode.position.y)
        if let gridPos = gridPositionForPiece(scenePoint: pieceLocation, piece: piece) {
            if gridPos != lastHoveredCell {
                lastHoveredCell = gridPos
                showGhostPreview(piece: piece, at: gridPos)

                // Haptic on cell change
                if gameState.grid.canPlacePiece(piece, at: gridPos) {
                    HapticManager.shared.hoverCell()
                    AudioManager.shared.play(.hoverCell)
                }
            }
        } else {
            clearGhostPreview()
            lastHoveredCell = nil
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = touches.first, let draggedNode = draggedPieceNode,
              let pieceIndex = draggedPieceIndex,
              let piece = gameState.availablePieces[pieceIndex] else {
            cleanupDrag()
            return
        }

        let pieceLocation = draggedNode.position

        if let gridPos = gridPositionForPiece(scenePoint: pieceLocation, piece: piece),
           gameState.grid.canPlacePiece(piece, at: gridPos) {
            // Valid placement
            placePieceOnGrid(piece: piece, at: gridPos, trayIndex: pieceIndex, dragNode: draggedNode)
        } else {
            // Invalid — return to tray
            returnPieceToTray(pieceIndex: pieceIndex, dragNode: draggedNode)
        }

        clearGhostPreview()
        cleanupDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let pieceIndex = draggedPieceIndex, let dragNode = draggedPieceNode {
            returnPieceToTray(pieceIndex: pieceIndex, dragNode: dragNode)
        }
        clearGhostPreview()
        cleanupDrag()
    }

    // MARK: - Drag Helpers

    private func startDragging(pieceIndex: Int, from location: CGPoint) {
        guard let piece = gameState.availablePieces[pieceIndex] else { return }

        draggedPieceIndex = pieceIndex

        // Hide the tray piece
        let slot = pieceTrays[pieceIndex]
        slot.children.filter { $0.name == "piecePreview" }.forEach { $0.alpha = 0.2 }

        // Create full-scale dragged piece
        let dragNode = createPieceNode(piece: piece, scale: 1.0)
        dragNode.position = CGPoint(x: location.x, y: location.y + cellSize * 2)
        dragNode.zPosition = 50
        dragNode.setScale(0.6)
        addChild(dragNode)

        // Pop animation to full scale
        dragNode.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.15),
            SKAction.fadeAlpha(to: 0.9, duration: 0.1)
        ]))

        draggedPieceNode = dragNode

        // Haptic + sound
        HapticManager.shared.piecePickup()
        AudioManager.shared.play(.piecePickup)
    }

    private func placePieceOnGrid(piece: BlockPiece, at position: GridPosition, trayIndex: Int, dragNode: SKNode) {
        // Place in game state
        let result = gameState.placePiece(piece, at: position, trayIndex: trayIndex)

        // Remove drag node
        dragNode.removeFromParent()

        // Refresh grid visually
        refreshGrid()

        // Squash-stretch landing animation on placed blocks
        for cell in piece.cells {
            let r = position.row + cell.row
            let c = position.col + cell.col
            if let blockNode = blockNodes[r][c] {
                blockNode.run(SKAction.squashLanding())
            }
        }

        // Detect tight fit for bonus feedback
        let isTight = BoardAnalyzer.isTightFit(piece: piece, at: position, on: gameState.grid)
        if isTight {
            HapticManager.shared.tightFit()
            AudioManager.shared.play(.tightFit)

            // Show "Tight!" label
            let tightLabel = SKLabelNode(text: "Tight! ✨")
            tightLabel.fontName = "SF Pro Display Bold"
            tightLabel.fontSize = 14
            tightLabel.fontColor = .cyan
            let worldPos = gridNode.convert(positionForCell(row: position.row, col: position.col), to: self)
            tightLabel.position = CGPoint(x: worldPos.x, y: worldPos.y + 20)
            tightLabel.zPosition = 70
            tightLabel.alpha = 0
            addChild(tightLabel)
            tightLabel.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.moveBy(x: 0, y: 25, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
        } else {
            HapticManager.shared.piecePlaced()
            AudioManager.shared.play(.placeBlock)
        }

        refreshPieceTray()

        // Tutorial: piece placed
        tutorial?.onPiecePlaced()

        // Handle clear results
        if let clearResult = result, !clearResult.isEmpty {
            animateLineClear(result: clearResult)

            // Tutorial: line cleared
            tutorial?.onLineCleared()

            // Score event
            if let scoreEvent = gameState.lastScoreEvent {
                if let msg = scoreEvent.message {
                    showReinforcementMessage(msg, comboLevel: scoreEvent.comboLevel)
                }
                if scoreEvent.comboLevel >= 2 {
                    // Tutorial: combo
                    tutorial?.onCombo()

                    if let comboMsg = gameState.scoreEngine.comboMessage() {
                        showComboMessage(comboMsg, level: scoreEvent.comboLevel)
                    }
                }
                showScorePopup(points: scoreEvent.points, at: gridNode.position + CGPoint(x: cellSize * 4, y: cellSize * 4))

                if scoreEvent.isNewHighScore {
                    animateNewHighScore()
                }

                // Zone state: track combo hit
                let wasInZone = zoneManager.isInZone
                zoneManager.onComboHit(level: scoreEvent.comboLevel)

                // Enter zone mode visually
                if zoneManager.isInZone && !wasInZone {
                    enterZoneMode()
                }

                // Show zone combo messages
                if zoneManager.isInZone {
                    showZoneComboMessage()
                    updateZoneIntensity()
                }
            }
        } else {
            // No lines cleared — combo breaks
            if zoneManager.isInZone {
                exitZoneMode()
            }
            zoneManager.onComboBreak()
        }

        // Update power-up bar
        updatePowerUpBar()

        // Check near-death state
        if gameState.phase != .gameOver {
            checkNearDeathState()
        }

        // Check for game over
        if gameState.phase == .gameOver {
            hideNearDeathWarning()
            animateGameOver()
        }
    }

    private func returnPieceToTray(pieceIndex: Int, dragNode: SKNode) {
        let slot = pieceTrays[pieceIndex]
        let targetPos = slot.convert(CGPoint.zero, to: self)

        HapticManager.shared.invalidPlacement()
        AudioManager.shared.play(.invalidPlacement)

        dragNode.run(SKAction.sequence([
            SKAction.group([
                SKAction.move(to: targetPos, duration: 0.2),
                SKAction.scale(to: 0.6, duration: 0.2)
            ]),
            SKAction.removeFromParent()
        ])) {
            // Restore tray piece visibility
            slot.children.filter { $0.name == "piecePreview" }.forEach { $0.alpha = 1.0 }
        }
    }

    private func cleanupDrag() {
        draggedPieceIndex = nil
        draggedPieceNode = nil
        lastHoveredCell = nil
    }

    // MARK: - Button Handlers

    private func handlePauseButtonTap() {
        HapticManager.shared.buttonTap()
        AudioManager.shared.play(.buttonTap)

        if gameState.phase == .playing {
            gameState.pause()
            showPauseOverlay()
        } else if gameState.phase == .paused {
            gameState.resume()
            hidePauseOverlay()
        }
    }

    // MARK: - Power-Up Mode

    private func handlePowerUpTap(type: PowerUpType, at location: CGPoint) {
        if let gridPos = gridPositionFor(scenePoint: location) {
            let affected = gameState.executePowerUp(type, target: gridPos)
            if !affected.isEmpty {
                animatePowerUpEffect(type: type, affected: affected)
                HapticManager.shared.powerUpActivated()
                AudioManager.shared.play(.powerUpUse)
                AudioManager.shared.duckMusic()
            }
            hidePowerUpModeIndicator()
            refreshGrid()
            updatePowerUpBar()
        } else {
            // Tapped outside grid — cancel
            gameState.cancelPowerUpMode()
            hidePowerUpModeIndicator()
        }
    }

    private func showPowerUpModeIndicator(_ type: PowerUpType) {
        // Dim non-grid elements
        let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.3), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 8
        overlay.name = "powerUpOverlay"
        addChild(overlay)

        // Instruction label
        let label = SKLabelNode(text: "Tap a cell to use \(type.displayName)")
        label.fontName = "SF Pro Display Bold"
        label.fontSize = 18
        label.fontColor = theme.uiAccentColor
        label.position = CGPoint(x: size.width / 2, y: gridOrigin.y - 50)
        label.zPosition = 9
        label.name = "powerUpInstruction"
        addChild(label)

        // Pulsing border on grid
        gridNode.pulseForever(minAlpha: 0.8, maxAlpha: 1.0, duration: 0.6)
    }

    private func hidePowerUpModeIndicator() {
        childNode(withName: "powerUpOverlay")?.removeFromParent()
        childNode(withName: "powerUpInstruction")?.removeFromParent()
        gridNode.stopPulse()
    }

    // MARK: - Pause Overlay

    private func showPauseOverlay() {
        let overlay = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 90
        overlay.name = "pauseOverlay"
        overlay.alpha = 0
        addChild(overlay)

        let pauseLabel = SKLabelNode(text: "PAUSED")
        pauseLabel.fontName = "SF Pro Display Heavy"
        pauseLabel.fontSize = 40
        pauseLabel.fontColor = .white
        pauseLabel.position = CGPoint(x: 0, y: 30)
        overlay.addChild(pauseLabel)

        let resumeLabel = SKLabelNode(text: "Tap to Resume")
        resumeLabel.fontName = "SF Pro Display"
        resumeLabel.fontSize = 18
        resumeLabel.fontColor = .white.withAlphaComponent(0.7)
        resumeLabel.position = CGPoint(x: 0, y: -20)
        overlay.addChild(resumeLabel)

        overlay.run(SKAction.fadeIn(withDuration: 0.2))
    }

    private func hidePauseOverlay() {
        if let overlay = childNode(withName: "pauseOverlay") {
            overlay.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.removeFromParent()
            ]))
        }
    }
}

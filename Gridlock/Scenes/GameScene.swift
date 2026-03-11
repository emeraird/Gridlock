import SpriteKit
import Combine
import os.log

final class GameScene: SKScene {
    // MARK: - Properties

    let logger = Logger(subsystem: "com.gridlock.app", category: "GameScene")

    // Game state
    let gameState = GameState()
    var cancellables = Set<AnyCancellable>()

    // Layout
    var cellSize: CGFloat = 40
    var gridOrigin: CGPoint = .zero
    let gridSize = GridModel.gridSize

    // Nodes
    var gridNode: SKNode!
    var cellNodes: [[SKSpriteNode]] = []
    var blockNodes: [[SKSpriteNode?]] = []
    var pieceTrays: [SKNode] = []
    var ghostNodes: [SKSpriteNode] = []

    // Drag state
    var draggedPieceIndex: Int?
    var draggedPieceNode: SKNode?
    var dragOffset: CGPoint = .zero
    var currentGhostPosition: GridPosition?
    var lastHoveredCell: GridPosition?

    // UI nodes
    var scoreLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!
    var comboLabel: SKLabelNode!
    var pauseButton: SKSpriteNode!
    var powerUpBar: SKNode!
    var ghostTickerNode: SKNode?
    var ghostTickerLabel: SKLabelNode?

    // Ghost competitors
    let ghostManager = GhostCompetitorManager()

    // Zone state
    let zoneManager = ZoneStateManager()
    var zoneOverlayNode: SKNode?

    // Milestone manager
    let milestoneManager = MilestoneManager()

    // Theme
    var theme: GameTheme { ThemeManager.shared.currentTheme }

    // MARK: - Lifecycle

    // Tutorial
    var tutorial: TutorialOverlay?

    override func didMove(to view: SKView) {
        backgroundColor = theme.backgroundColor
        setupLayout()
        setupGrid()
        setupPieceTray()
        setupUI()
        bindState()

        gameState.startNewGame()
        refreshGrid()
        refreshPieceTray()

        // Session & ad tracking
        SessionManager.shared.onGameStart()
        AdManager.shared.onGameStart()
        NotificationScheduler.onGamePlayed()

        // Apply mercy mode if player is struggling
        if SessionManager.shared.mercyBonusPieces {
            gameState.pieceGenerator.isTutorialMode = true
            run(SKAction.wait(forDuration: 0.5)) { [weak self] in
                self?.gameState.pieceGenerator.isTutorialMode = false
            }
        }

        // Zone state reset
        zoneManager.resetForNewGame()
        zoneOverlayNode?.removeFromParent()
        zoneOverlayNode = nil

        // Milestone reset
        milestoneManager.resetForNewGame()

        // Ghost competitors
        ghostManager.generateGhosts(playerHighScore: gameState.scoreEngine.highScore)
        ghostManager.startUpdating()
        setupGhostTicker()

        // Start tutorial on first game
        if !UserProgressManager.shared.tutorialCompleted {
            tutorial = TutorialOverlay(scene: self)
            tutorial?.startTutorial()
        }

        // Show daily reward popup
        if DailyRewardManager.shared.hasUncollectedReward {
            run(SKAction.wait(forDuration: 0.5)) { [weak self] in
                self?.showDailyRewardPopup()
            }
        }
    }

    // MARK: - Layout Calculation

    private func setupLayout() {
        guard let view = self.view else { return }

        let safeArea = view.safeAreaInsets
        let screenWidth = size.width
        let screenHeight = size.height

        // Grid takes ~80% of screen width
        let gridWidth = screenWidth * 0.85
        cellSize = floor(gridWidth / CGFloat(gridSize))
        let totalGridSize = cellSize * CGFloat(gridSize)

        // Center horizontally, position in upper 60%
        let gridX = (screenWidth - totalGridSize) / 2
        let topMargin = safeArea.top + 80  // Space for score UI
        let gridY = screenHeight - topMargin - totalGridSize

        gridOrigin = CGPoint(x: gridX, y: gridY)

        logger.info("Layout: cellSize=\(self.cellSize), gridOrigin=(\(gridX), \(gridY)), screen=\(screenWidth)x\(screenHeight)")
    }

    // MARK: - Grid Setup

    private func setupGrid() {
        gridNode = SKNode()
        gridNode.position = gridOrigin
        gridNode.zPosition = 1
        addChild(gridNode)

        // Grid background
        let bgTexture = TextureGenerator.shared.gridBackgroundTexture(
            gridSize: gridSize, cellSize: cellSize,
            backgroundColor: theme.gridBackgroundColor,
            lineColor: theme.gridLineColor,
            cellColor: theme.cellEmptyColor
        )
        let bgNode = SKSpriteNode(texture: bgTexture)
        let totalSize = cellSize * CGFloat(gridSize)
        bgNode.size = CGSize(width: totalSize, height: totalSize)
        bgNode.anchorPoint = .zero
        bgNode.zPosition = 0
        gridNode.addChild(bgNode)

        // Initialize cell and block node arrays
        cellNodes = Array(repeating: Array(repeating: SKSpriteNode(), count: gridSize), count: gridSize)
        blockNodes = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)

        // Create empty cell nodes (for visual reference, blocks are placed on top)
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let cellNode = SKSpriteNode()
                cellNode.size = CGSize(width: cellSize - 2, height: cellSize - 2)
                cellNode.position = positionForCell(row: row, col: col)
                cellNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                cellNode.zPosition = 1
                cellNode.name = "cell_\(row)_\(col)"
                gridNode.addChild(cellNode)
                cellNodes[row][col] = cellNode
            }
        }
    }

    // MARK: - Piece Tray

    private func setupPieceTray() {
        let trayY = gridOrigin.y - 130
        let trayWidth = size.width
        let slotWidth = trayWidth / 3

        for i in 0..<3 {
            let slot = SKNode()
            slot.position = CGPoint(x: slotWidth * CGFloat(i) + slotWidth / 2, y: trayY)
            slot.name = "traySlot_\(i)"
            slot.zPosition = 5

            // Slot background
            let slotBg = SKSpriteNode(texture: TextureGenerator.shared.traySlotTexture(
                size: CGSize(width: slotWidth - 20, height: 100),
                color: theme.gridLineColor
            ))
            slotBg.zPosition = -1
            slot.addChild(slotBg)

            addChild(slot)
            pieceTrays.append(slot)
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Score label
        scoreLabel = SKLabelNode(fontNamed: "SF Pro Display Bold")
        scoreLabel.fontSize = 28
        scoreLabel.fontColor = theme.scoreTextColor
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 20, y: size.height - 60)
        scoreLabel.zPosition = 100
        scoreLabel.text = "0"
        addChild(scoreLabel)

        // High score label
        highScoreLabel = SKLabelNode(fontNamed: "SF Pro Display")
        highScoreLabel.fontSize = 14
        highScoreLabel.fontColor = theme.scoreTextColor.withAlphaComponent(0.6)
        highScoreLabel.horizontalAlignmentMode = .right
        highScoreLabel.position = CGPoint(x: size.width - 20, y: size.height - 55)
        highScoreLabel.zPosition = 100
        highScoreLabel.text = "best: \(gameState.scoreEngine.highScore)"
        addChild(highScoreLabel)

        // Combo label (hidden by default)
        comboLabel = SKLabelNode(fontNamed: "SF Pro Display Heavy")
        comboLabel.fontSize = 20
        comboLabel.fontColor = theme.comboTextColors.first ?? .white
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height - 55)
        comboLabel.zPosition = 100
        comboLabel.alpha = 0
        addChild(comboLabel)

        // Pause button
        pauseButton = SKSpriteNode(color: .clear, size: CGSize(width: 44, height: 44))
        pauseButton.position = CGPoint(x: size.width - 35, y: size.height - 30)
        pauseButton.zPosition = 100
        pauseButton.name = "pauseButton"

        let pauseIcon = SKLabelNode(text: "||")
        pauseIcon.fontName = "SF Pro Display Bold"
        pauseIcon.fontSize = 20
        pauseIcon.fontColor = theme.scoreTextColor.withAlphaComponent(0.7)
        pauseIcon.verticalAlignmentMode = .center
        pauseButton.addChild(pauseIcon)
        addChild(pauseButton)

        // Power-up bar
        setupPowerUpBar()
    }

    private func setupPowerUpBar() {
        powerUpBar = SKNode()
        let barY = gridOrigin.y - 30
        powerUpBar.position = CGPoint(x: size.width / 2, y: barY)
        powerUpBar.zPosition = 10
        addChild(powerUpBar)

        updatePowerUpBar()
    }

    func updatePowerUpBar() {
        powerUpBar.removeAllChildren()

        let types = PowerUpType.allCases
        let spacing: CGFloat = 70
        let totalWidth = spacing * CGFloat(types.count - 1)
        let startX = -totalWidth / 2

        for (i, type) in types.enumerated() {
            let count = gameState.powerUpSystem.count(of: type)
            let button = createPowerUpButton(type: type, count: count)
            button.position = CGPoint(x: startX + spacing * CGFloat(i), y: 0)
            button.name = "powerUp_\(type.rawValue)"
            powerUpBar.addChild(button)
        }
    }

    func createPowerUpButton(type: PowerUpType, count: Int) -> SKNode {
        let node = SKNode()
        let isActive = count > 0
        let canWatchAd = !isActive && AdManager.shared.canShowRewardedAd(placement: .freePowerUp)
        let iconColor = isActive ? theme.uiAccentColor : (canWatchAd ? UIColor(hex: "4CAF50") : UIColor.gray)

        // Icon background circle
        let circle = SKShapeNode(circleOfRadius: 22)
        circle.fillColor = isActive ? theme.uiAccentColor.withAlphaComponent(0.25) :
            (canWatchAd ? UIColor(hex: "4CAF50").withAlphaComponent(0.15) : UIColor.gray.withAlphaComponent(0.1))
        circle.strokeColor = isActive ? theme.uiAccentColor :
            (canWatchAd ? UIColor(hex: "4CAF50").withAlphaComponent(0.5) : UIColor.gray.withAlphaComponent(0.3))
        circle.lineWidth = 1.5
        node.addChild(circle)

        // SF Symbol icon rendered as texture
        let symbolName = canWatchAd ? "play.circle.fill" : type.iconName
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        if let symbolImage = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal) {
            let texture = SKTexture(image: symbolImage)
            let iconSprite = SKSpriteNode(texture: texture)
            iconSprite.size = CGSize(width: 22, height: 22)
            iconSprite.position = CGPoint(x: 0, y: 2)
            iconSprite.zPosition = 1
            node.addChild(iconSprite)
        }

        // Label underneath
        let labelText = canWatchAd ? "Free!" : type.displayName
        let nameLabel = SKLabelNode(text: labelText)
        nameLabel.fontName = "SF Pro Display Medium"
        nameLabel.fontSize = 9
        nameLabel.fontColor = isActive ? .white.withAlphaComponent(0.8) :
            (canWatchAd ? UIColor(hex: "4CAF50").withAlphaComponent(0.9) : .gray.withAlphaComponent(0.5))
        nameLabel.verticalAlignmentMode = .top
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -27)
        node.addChild(nameLabel)

        // Count badge
        if count > 0 {
            let badge = SKShapeNode(circleOfRadius: 9)
            badge.position = CGPoint(x: 16, y: 16)
            badge.fillColor = theme.uiAccentColor
            badge.strokeColor = .clear
            badge.zPosition = 2
            node.addChild(badge)

            let countLabel = SKLabelNode(text: "\(count)")
            countLabel.fontSize = 11
            countLabel.fontName = "SF Pro Display Bold"
            countLabel.fontColor = .white
            countLabel.verticalAlignmentMode = .center
            countLabel.horizontalAlignmentMode = .center
            countLabel.position = badge.position
            countLabel.zPosition = 3
            node.addChild(countLabel)
        }

        return node
    }

    func powerUpEmoji(_ type: PowerUpType) -> String {
        // Fallback text for animations
        switch type {
        case .bomb: return "💣"
        case .lineBlast: return "⚡"
        case .undo: return "↩️"
        case .shuffle: return "🔀"
        }
    }

    // MARK: - Ghost Ticker

    private func setupGhostTicker() {
        let tickerNode = SKNode()
        tickerNode.position = CGPoint(x: size.width / 2, y: size.height - 18)
        tickerNode.zPosition = 99
        addChild(tickerNode)
        ghostTickerNode = tickerNode

        let label = SKLabelNode(fontNamed: "SF Pro Display Medium")
        label.fontSize = 10
        label.fontColor = .white.withAlphaComponent(0.6)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        tickerNode.addChild(label)
        ghostTickerLabel = label

        // Background bar
        let bg = SKShapeNode(rectOf: CGSize(width: size.width - 20, height: 18), cornerRadius: 4)
        bg.fillColor = UIColor.black.withAlphaComponent(0.3)
        bg.strokeColor = .clear
        bg.zPosition = -1
        tickerNode.addChild(bg)
    }

    func updateGhostTicker() {
        guard let label = ghostTickerLabel else { return }
        let standings = ghostManager.finalStandings()
        let parts = standings.prefix(3).map { entry -> String in
            let name = entry.isPlayer ? "You" : entry.name
            return "\(entry.emoji) \(name) — \(entry.score)"
        }
        label.text = parts.joined(separator: "  |  ")
    }

    func handleGhostOvertake(_ event: GhostCompetitorManager.OvertakeEvent) {
        if event.playerOvertook {
            // Player passed a ghost — celebration
            let label = SKLabelNode(text: "You passed \(event.ghostName)!")
            label.fontName = "SF Pro Display Bold"
            label.fontSize = 14
            label.fontColor = .green
            label.position = CGPoint(x: size.width / 2, y: size.height - 40)
            label.zPosition = 98
            label.alpha = 0
            addChild(label)
            label.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.wait(forDuration: 1.0),
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
            HapticManager.shared.buttonTap()
            AudioManager.shared.play(.buttonTap)
        } else {
            // Ghost passed player — alert
            ghostTickerNode?.run(SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.1),
                SKAction.wait(forDuration: 0.3),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.2)
            ]))
        }
    }

    // MARK: - State Binding

    private func bindState() {
        // Observe score changes
        gameState.scoreEngine.$currentScore
            .receive(on: RunLoop.main)
            .sink { [weak self] score in
                guard let self = self else { return }
                self.scoreLabel.text = "\(score)"
                self.ghostManager.updatePlayerScore(score)
                self.updateGhostTicker()
                // Check milestones
                self.milestoneManager.checkScore(score, powerUpSystem: self.gameState.powerUpSystem)
            }
            .store(in: &cancellables)

        // Observe ghost overtake events
        ghostManager.$lastOvertakeEvent
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleGhostOvertake(event)
            }
            .store(in: &cancellables)

        // Observe piece changes — refresh tray when new pieces arrive
        gameState.$availablePieces
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPieceTray()
            }
            .store(in: &cancellables)

        // Observe power-up earned events
        gameState.powerUpSystem.earnedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.animatePowerUpEarned(event.type)
                self?.updatePowerUpBar()
            }
            .store(in: &cancellables)

        // Observe milestone events
        milestoneManager.milestonePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.animateMilestone(event)
                // Apply bonus points if milestone gives them
                if event.reward.bonusPoints > 0 {
                    self?.gameState.scoreEngine.addBonusPoints(event.reward.bonusPoints)
                }
                self?.updatePowerUpBar()
            }
            .store(in: &cancellables)
    }

    // MARK: - Grid Rendering

    func refreshGrid() {
        let grid = gameState.grid

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                // Remove existing block node
                blockNodes[row][col]?.removeFromParent()
                blockNodes[row][col] = nil

                if let color = grid.getCell(row: row, col: col) {
                    let uiColor = theme.blockColor(for: color)
                    let blockSize = CGSize(width: cellSize - 2, height: cellSize - 2)
                    let blockNode = SKSpriteNode(
                        texture: TextureGenerator.shared.blockTexture(color: uiColor, size: blockSize),
                        size: blockSize
                    )
                    blockNode.position = positionForCell(row: row, col: col)
                    blockNode.zPosition = 2
                    gridNode.addChild(blockNode)
                    blockNodes[row][col] = blockNode
                }
            }
        }
    }

    func refreshPieceTray() {
        for (index, slot) in pieceTrays.enumerated() {
            // Remove old piece preview
            slot.children.filter { $0.name == "piecePreview" }.forEach { $0.removeFromParent() }

            guard let piece = gameState.availablePieces[safe: index] ?? nil else { continue }

            let previewNode = createPieceNode(piece: piece, scale: 0.6)
            previewNode.name = "piecePreview"
            previewNode.zPosition = 1
            slot.addChild(previewNode)
        }
    }

    // MARK: - Piece Node Creation

    func createPieceNode(piece: BlockPiece, scale: CGFloat = 1.0) -> SKNode {
        let container = SKNode()
        let blockSize = cellSize * scale
        let uiColor = theme.blockColor(for: piece.color)

        // Center the piece
        let centerOffsetX = -CGFloat(piece.width) * blockSize / 2 + blockSize / 2
        let centerOffsetY = -CGFloat(piece.height) * blockSize / 2 + blockSize / 2

        for cell in piece.cells {
            let sprite = SKSpriteNode(
                texture: TextureGenerator.shared.blockTexture(
                    color: uiColor,
                    size: CGSize(width: blockSize - 2, height: blockSize - 2)
                ),
                size: CGSize(width: blockSize - 2, height: blockSize - 2)
            )
            sprite.position = CGPoint(
                x: CGFloat(cell.col) * blockSize + centerOffsetX,
                y: -CGFloat(cell.row) * blockSize - centerOffsetY
            )
            container.addChild(sprite)
        }

        return container
    }

    // MARK: - Position Helpers

    func positionForCell(row: Int, col: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col) * cellSize + cellSize / 2,
            y: CGFloat(gridSize - 1 - row) * cellSize + cellSize / 2
        )
    }

    func gridPositionFor(scenePoint: CGPoint) -> GridPosition? {
        let localPoint = gridNode.convert(scenePoint, from: self)
        let col = Int(localPoint.x / cellSize)
        let row = gridSize - 1 - Int(localPoint.y / cellSize)

        guard row >= 0 && row < gridSize && col >= 0 && col < gridSize else { return nil }
        return GridPosition(row: row, col: col)
    }

    /// Convert scene point to grid position for piece placement (top-left origin)
    func gridPositionForPiece(scenePoint: CGPoint, piece: BlockPiece) -> GridPosition? {
        let localPoint = gridNode.convert(scenePoint, from: self)
        // Offset to center the piece on the finger
        let col = Int((localPoint.x - CGFloat(piece.width) * cellSize / 2 + cellSize / 2) / cellSize)
        let row = gridSize - 1 - Int((localPoint.y + CGFloat(piece.height) * cellSize / 2 - cellSize / 2) / cellSize)

        return GridPosition(row: row, col: col)
    }

    // MARK: - Ghost Preview

    func showGhostPreview(piece: BlockPiece, at position: GridPosition) {
        clearGhostPreview()

        let valid = gameState.grid.canPlacePiece(piece, at: position)
        let ghostSize = CGSize(width: cellSize - 2, height: cellSize - 2)
        let texture = TextureGenerator.shared.ghostTexture(color: .clear, size: ghostSize, valid: valid)

        for cell in piece.cells {
            let row = position.row + cell.row
            let col = position.col + cell.col
            guard gameState.grid.isValidPosition(row: row, col: col) else { continue }

            let ghost = SKSpriteNode(texture: texture, size: ghostSize)
            ghost.position = positionForCell(row: row, col: col)
            ghost.zPosition = 3
            ghost.alpha = 0.8
            gridNode.addChild(ghost)
            ghostNodes.append(ghost)
        }

        currentGhostPosition = position
    }

    func clearGhostPreview() {
        ghostNodes.forEach { $0.removeFromParent() }
        ghostNodes.removeAll()
        currentGhostPosition = nil
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        // Frame update logic if needed
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

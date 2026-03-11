import SpriteKit

extension SKNode {
    /// Run an action sequence with a completion block
    func runSequence(_ actions: [SKAction], completion: @escaping () -> Void = {}) {
        run(SKAction.sequence(actions), completion: completion)
    }

    /// Run action group (parallel)
    func runGroup(_ actions: [SKAction], completion: @escaping () -> Void = {}) {
        run(SKAction.group(actions), completion: completion)
    }

    /// Fade in with duration
    func fadeInWith(duration: TimeInterval = 0.3) {
        alpha = 0
        run(SKAction.fadeIn(withDuration: duration))
    }

    /// Fade out and remove
    func fadeOutAndRemove(duration: TimeInterval = 0.3) {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: duration),
            SKAction.removeFromParent()
        ]))
    }

    /// Pop scale animation (scale up then back to normal)
    func popIn(scale: CGFloat = 1.2, duration: TimeInterval = 0.15) {
        setScale(0.01)
        run(SKAction.sequence([
            SKAction.scale(to: scale, duration: duration * 0.6),
            SKAction.scale(to: 1.0, duration: duration * 0.4)
        ]))
    }

    /// Bounce animation
    func bounce(height: CGFloat = 5, duration: TimeInterval = 0.2) {
        let up = SKAction.moveBy(x: 0, y: height, duration: duration * 0.4)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -height, duration: duration * 0.6)
        down.timingMode = .easeIn
        run(SKAction.sequence([up, down]))
    }

    /// Shake animation for screen shake
    func shake(amplitude: CGFloat = 2, duration: TimeInterval = 0.15) {
        let shakeCount = 4
        let shakeDuration = duration / Double(shakeCount * 2)
        var actions: [SKAction] = []
        for _ in 0..<shakeCount {
            let dx = CGFloat.random(in: -amplitude...amplitude)
            let dy = CGFloat.random(in: -amplitude...amplitude)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: shakeDuration))
            actions.append(SKAction.moveBy(x: -dx, y: -dy, duration: shakeDuration))
        }
        run(SKAction.sequence(actions))
    }

    /// Pulse glow effect
    func pulseForever(minAlpha: CGFloat = 0.6, maxAlpha: CGFloat = 1.0, duration: TimeInterval = 0.8) {
        let fadeOut = SKAction.fadeAlpha(to: minAlpha, duration: duration / 2)
        let fadeIn = SKAction.fadeAlpha(to: maxAlpha, duration: duration / 2)
        run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])), withKey: "pulse")
    }

    func stopPulse() {
        removeAction(forKey: "pulse")
        alpha = 1.0
    }
}

extension SKSpriteNode {
    /// Create a colored block sprite with rounded corners and bevel effect
    static func blockSprite(size: CGSize, color: UIColor, cornerRadius: CGFloat = 4) -> SKSpriteNode {
        let texture = TextureGenerator.shared.blockTexture(color: color, size: size, cornerRadius: cornerRadius)
        let node = SKSpriteNode(texture: texture, size: size)
        return node
    }
}

extension SKAction {
    /// Ease-out-bounce timing curve
    static func bounceIn(to scale: CGFloat, duration: TimeInterval) -> SKAction {
        let overshoot = SKAction.scale(to: scale * 1.15, duration: duration * 0.7)
        overshoot.timingMode = .easeOut
        let settle = SKAction.scale(to: scale, duration: duration * 0.3)
        settle.timingMode = .easeIn
        return SKAction.sequence([overshoot, settle])
    }

    /// Squash-and-stretch landing animation
    static func squashLanding(duration: TimeInterval = 0.12) -> SKAction {
        let squash = SKAction.group([
            SKAction.scaleX(to: 1.15, duration: duration * 0.4),
            SKAction.scaleY(to: 0.85, duration: duration * 0.4)
        ])
        let recover = SKAction.group([
            SKAction.scaleX(to: 0.95, duration: duration * 0.3),
            SKAction.scaleY(to: 1.05, duration: duration * 0.3)
        ])
        let settle = SKAction.scale(to: 1.0, duration: duration * 0.3)
        return SKAction.sequence([squash, recover, settle])
    }

    /// Jelly wobble animation (for tight fits)
    static func jellyWobble(duration: TimeInterval = 0.3) -> SKAction {
        var actions: [SKAction] = []
        let wobbleCount = 3
        for i in 0..<wobbleCount {
            let intensity = 1.0 - (Double(i) / Double(wobbleCount))
            let angle = CGFloat(0.03 * intensity)
            actions.append(SKAction.rotate(byAngle: angle, duration: duration / Double(wobbleCount * 2)))
            actions.append(SKAction.rotate(byAngle: -angle * 2, duration: duration / Double(wobbleCount * 2)))
        }
        actions.append(SKAction.rotate(toAngle: 0, duration: duration * 0.1))
        return SKAction.sequence(actions)
    }

    /// Count-up number animation
    static func countUp(from start: Int, to end: Int, duration: TimeInterval, update: @escaping (Int) -> Void) -> SKAction {
        let steps = 30
        let stepDuration = duration / Double(steps)
        var actions: [SKAction] = []
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            let eased = progress * progress * (3 - 2 * progress) // smoothstep
            let value = start + Int(Double(end - start) * eased)
            actions.append(SKAction.run { update(value) })
            if i < steps {
                actions.append(SKAction.wait(forDuration: stepDuration))
            }
        }
        return SKAction.sequence(actions)
    }
}

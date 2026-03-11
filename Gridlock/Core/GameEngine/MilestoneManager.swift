import Foundation
import Combine
import os.log

// MARK: - Milestone Definition

struct Milestone {
    let scoreThreshold: Int
    let title: String
    let emoji: String
    let rewardType: MilestoneReward

    enum MilestoneReward {
        case powerUp(PowerUpType)
        case randomPowerUp
        case bonusPoints(Int)
        case multiplePowerUps([(PowerUpType, Int)]) // type + count
    }
}

// MARK: - Milestone Event

struct MilestoneEvent {
    let milestone: Milestone
    let reward: MilestoneRewardResult
    let isFirstTime: Bool
}

struct MilestoneRewardResult {
    let description: String
    let powerUpsEarned: [(type: PowerUpType, count: Int)]
    let bonusPoints: Int
}

// MARK: - Milestone Manager

final class MilestoneManager: ObservableObject {
    @Published private(set) var milestonesHitThisGame: [Int] = []

    let milestonePublisher = PassthroughSubject<MilestoneEvent, Never>()

    private let logger = Logger(subsystem: "com.gridlock.app", category: "MilestoneManager")
    private let allTimeMilestonesKey = "allTimeMilestones"

    // All score milestones in order
    static let milestones: [Milestone] = [
        Milestone(scoreThreshold: 100, title: "Warming Up", emoji: "🌡️",
                  rewardType: .bonusPoints(25)),
        Milestone(scoreThreshold: 250, title: "Getting Started", emoji: "🚶",
                  rewardType: .randomPowerUp),
        Milestone(scoreThreshold: 500, title: "Half a Grand", emoji: "💰",
                  rewardType: .powerUp(.bomb)),
        Milestone(scoreThreshold: 1000, title: "1K Club", emoji: "🎯",
                  rewardType: .randomPowerUp),
        Milestone(scoreThreshold: 1500, title: "On a Roll", emoji: "🎲",
                  rewardType: .bonusPoints(100)),
        Milestone(scoreThreshold: 2000, title: "Two Thousand", emoji: "✌️",
                  rewardType: .powerUp(.lineBlast)),
        Milestone(scoreThreshold: 2500, title: "Quarter Master", emoji: "⚔️",
                  rewardType: .randomPowerUp),
        Milestone(scoreThreshold: 3000, title: "Triple Threat", emoji: "🔱",
                  rewardType: .bonusPoints(150)),
        Milestone(scoreThreshold: 4000, title: "Untouchable", emoji: "👑",
                  rewardType: .randomPowerUp),
        Milestone(scoreThreshold: 5000, title: "5K Legend", emoji: "🏆",
                  rewardType: .multiplePowerUps([(.bomb, 1), (.lineBlast, 1)])),
        Milestone(scoreThreshold: 7500, title: "Elite Player", emoji: "💎",
                  rewardType: .randomPowerUp),
        Milestone(scoreThreshold: 10000, title: "10K Master", emoji: "🌟",
                  rewardType: .multiplePowerUps([(.bomb, 2), (.lineBlast, 1), (.shuffle, 1)])),
        Milestone(scoreThreshold: 15000, title: "Unstoppable", emoji: "🔥",
                  rewardType: .randomPowerUp),
        Milestone(scoreThreshold: 20000, title: "20K Titan", emoji: "⚡",
                  rewardType: .multiplePowerUps([(.bomb, 2), (.lineBlast, 2), (.undo, 1)])),
        Milestone(scoreThreshold: 30000, title: "Gridlock God", emoji: "🌈",
                  rewardType: .multiplePowerUps([(.bomb, 3), (.lineBlast, 2), (.shuffle, 1), (.undo, 1)])),
    ]

    // MARK: - Check Milestones

    func checkScore(_ score: Int, powerUpSystem: PowerUpSystem) {
        for milestone in Self.milestones {
            guard score >= milestone.scoreThreshold else { continue }
            guard !milestonesHitThisGame.contains(milestone.scoreThreshold) else { continue }

            milestonesHitThisGame.append(milestone.scoreThreshold)

            let isFirstTime = !hasEverHitMilestone(milestone.scoreThreshold)
            if isFirstTime {
                recordMilestoneHit(milestone.scoreThreshold)
            }

            // Award reward
            let result = awardReward(milestone: milestone, powerUpSystem: powerUpSystem)

            let event = MilestoneEvent(
                milestone: milestone,
                reward: result,
                isFirstTime: isFirstTime
            )
            milestonePublisher.send(event)

            logger.info("Milestone hit: \(milestone.title) (\(milestone.scoreThreshold)pts), firstTime=\(isFirstTime)")
        }
    }

    private func awardReward(milestone: Milestone, powerUpSystem: PowerUpSystem) -> MilestoneRewardResult {
        var earnedPowerUps: [(type: PowerUpType, count: Int)] = []
        var bonusPoints = 0

        switch milestone.rewardType {
        case .powerUp(let type):
            powerUpSystem.earn(type, reason: "milestone: \(milestone.title)")
            earnedPowerUps.append((type, 1))

        case .randomPowerUp:
            let type = PowerUpType.allCases.randomElement() ?? .bomb
            powerUpSystem.earn(type, reason: "milestone: \(milestone.title)")
            earnedPowerUps.append((type, 1))

        case .bonusPoints(let points):
            bonusPoints = points

        case .multiplePowerUps(let rewards):
            for (type, count) in rewards {
                for _ in 0..<count {
                    powerUpSystem.earn(type, reason: "milestone: \(milestone.title)")
                }
                earnedPowerUps.append((type, count))
            }
        }

        let description: String
        if !earnedPowerUps.isEmpty {
            let parts = earnedPowerUps.map { "\($0.count)x \($0.type.displayName)" }
            description = parts.joined(separator: " + ")
        } else if bonusPoints > 0 {
            description = "+\(bonusPoints) bonus points"
        } else {
            description = ""
        }

        return MilestoneRewardResult(
            description: description,
            powerUpsEarned: earnedPowerUps,
            bonusPoints: bonusPoints
        )
    }

    // MARK: - Reset

    func resetForNewGame() {
        milestonesHitThisGame = []
    }

    // MARK: - All-Time Tracking

    private func hasEverHitMilestone(_ threshold: Int) -> Bool {
        let hit = UserDefaults.standard.array(forKey: allTimeMilestonesKey) as? [Int] ?? []
        return hit.contains(threshold)
    }

    private func recordMilestoneHit(_ threshold: Int) {
        var hit = UserDefaults.standard.array(forKey: allTimeMilestonesKey) as? [Int] ?? []
        if !hit.contains(threshold) {
            hit.append(threshold)
            UserDefaults.standard.set(hit, forKey: allTimeMilestonesKey)
        }
    }

    // MARK: - Query

    var nextMilestone: Milestone? {
        let hitSet = Set(milestonesHitThisGame)
        return Self.milestones.first { !hitSet.contains($0.scoreThreshold) }
    }

    func progressToNextMilestone(currentScore: Int) -> Double {
        guard let next = nextMilestone else { return 1.0 }
        let prevThreshold = Self.milestones
            .filter { milestonesHitThisGame.contains($0.scoreThreshold) }
            .map(\.scoreThreshold)
            .max() ?? 0
        let range = next.scoreThreshold - prevThreshold
        guard range > 0 else { return 0.0 }
        return min(1.0, Double(currentScore - prevThreshold) / Double(range))
    }
}

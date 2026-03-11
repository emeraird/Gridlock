import Foundation
import Combine
import os.log

// MARK: - Ghost Competitor

struct GhostCompetitor: Identifiable {
    let id = UUID()
    let name: String
    let avatarEmoji: String
    var score: Int
    let isRealPlayer: Bool
    let targetScore: Int        // Final score this ghost aims for
    let scoreRate: Double       // Points per second base rate
}

// MARK: - Ghost Competitor Manager

final class GhostCompetitorManager: ObservableObject {
    @Published private(set) var ghosts: [GhostCompetitor] = []
    @Published private(set) var playerRank: Int = 1
    @Published private(set) var lastOvertakeEvent: OvertakeEvent?

    private var updateTimer: Timer?
    private var playerScore: Int = 0
    private let logger = Logger(subsystem: "com.gridlock.app", category: "GhostCompetitor")

    struct OvertakeEvent {
        let ghostName: String
        let playerOvertook: Bool // true = player passed ghost, false = ghost passed player
        let timestamp: Date
    }

    // MARK: - Name Generation

    private static let firstNames = [
        "Alex", "Priya", "Jordan", "Yuki", "Maria", "Liam", "Fatima", "Noah",
        "Sara", "Mike", "Emma", "Chen", "Aisha", "Ben", "Luna", "Omar",
        "Mia", "Ryan", "Zara", "Tyler", "Hana", "Jake", "Chloe", "Dev",
        "Sophie", "Leo", "Ava", "Kai", "Ella", "Max", "Lily", "Sam",
        "Nora", "Ian", "Ruby", "Jay", "Maya", "Cole", "Isla", "Finn",
        "Aria", "Eli", "Grace", "Ravi", "Zoey", "Luke", "Amara", "Owen",
        "Leah", "Dan", "Nina", "Tom", "Jade", "Reese", "Kim", "Pat",
        "Dana", "Chris", "Tara", "Ash", "Sage", "Quinn", "Drew", "Rory"
    ]

    private static let lastInitials = "A B C D E F G H J K L M N O P R S T V W".components(separatedBy: " ")

    private static let avatarEmojis = [
        "😎", "🔥", "⭐", "💪", "🎯", "🏆", "✨", "🌟", "💎", "🎮",
        "🚀", "⚡", "🎲", "🧩", "🌈", "💫", "🦊", "🐱", "🎸", "🎨"
    ]

    // MARK: - Generate Ghosts

    func generateGhosts(playerHighScore: Int) {
        ghosts.removeAll()

        let baseScore = max(playerHighScore, 500)

        for _ in 0..<2 {
            let name = "\(Self.firstNames.randomElement()!) \(Self.lastInitials.randomElement()!)."
            let emoji = Self.avatarEmojis.randomElement()!

            // Ghost target score: close to player's ability
            let multiplier = Double.random(in: 0.85...1.15)
            let targetScore = Int(Double(baseScore) * multiplier)

            // Rate calculated to reach target in ~60-120 seconds of gameplay
            let gameDuration = Double.random(in: 60...120)
            let rate = Double(targetScore) / gameDuration

            let ghost = GhostCompetitor(
                name: name,
                avatarEmoji: emoji,
                score: 0,
                isRealPlayer: false,
                targetScore: targetScore,
                scoreRate: rate
            )
            ghosts.append(ghost)
        }

        playerRank = 1
        lastOvertakeEvent = nil
        logger.debug("Generated \(self.ghosts.count) ghost competitors")
    }

    // MARK: - Update Loop

    func startUpdating() {
        stopUpdating()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func updatePlayerScore(_ score: Int) {
        let oldRank = calculateRank(playerScore: playerScore)
        playerScore = score
        let newRank = calculateRank(playerScore: playerScore)

        if newRank != oldRank {
            playerRank = newRank

            // Detect overtake events
            if newRank < oldRank {
                // Player moved up — passed a ghost
                let passedGhost = ghosts.sorted(by: { $0.score > $1.score })
                    .first(where: { $0.score <= playerScore && $0.score > 0 })
                if let ghost = passedGhost {
                    lastOvertakeEvent = OvertakeEvent(ghostName: ghost.name, playerOvertook: true, timestamp: Date())
                }
            } else if newRank > oldRank {
                // Ghost passed the player
                let passingGhost = ghosts.sorted(by: { $0.score > $1.score })
                    .first(where: { $0.score >= playerScore })
                if let ghost = passingGhost {
                    lastOvertakeEvent = OvertakeEvent(ghostName: ghost.name, playerOvertook: false, timestamp: Date())
                }
            }
        }
    }

    private func tick() {
        for i in ghosts.indices {
            guard ghosts[i].score < ghosts[i].targetScore else { continue }

            // Add some variance to the rate
            let variance = Double.random(in: 0.3...1.8)
            let increment = Int(ghosts[i].scoreRate * variance)
            ghosts[i].score = min(ghosts[i].score + increment, ghosts[i].targetScore)
        }

        // Check for rank changes
        updatePlayerScore(playerScore)
    }

    private func calculateRank(playerScore: Int) -> Int {
        let higherGhosts = ghosts.filter { $0.score > playerScore }.count
        return higherGhosts + 1
    }

    // MARK: - Results

    func finalStandings() -> [(name: String, emoji: String, score: Int, isPlayer: Bool)] {
        var standings: [(name: String, emoji: String, score: Int, isPlayer: Bool)] = []
        standings.append(("You", "🎮", playerScore, true))
        for ghost in ghosts {
            standings.append((ghost.name, ghost.avatarEmoji, ghost.score, false))
        }
        standings.sort { $0.score > $1.score }
        return standings
    }

    var closestGhostAhead: GhostCompetitor? {
        ghosts.filter { $0.score > playerScore }
            .min(by: { $0.score < $1.score })
    }

    var pointsBehindLeader: Int? {
        guard let leader = closestGhostAhead else { return nil }
        return leader.score - playerScore
    }
}

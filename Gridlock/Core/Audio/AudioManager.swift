import AVFoundation
import Combine
import os.log

// MARK: - Sound Effect

enum SoundEffect: String, CaseIterable {
    case placeBlock = "place_block"
    case clearLine = "clear_line"
    case combo2x = "combo_2x"
    case combo3x = "combo_3x"
    case combo4x = "combo_4x"
    case combo5x = "combo_5x"
    case powerUpEarn = "power_up_earn"
    case powerUpUse = "power_up_use"
    case gameOver = "game_over"
    case highScore = "high_score"
    case buttonTap = "button_tap"
    case streakCelebrate = "streak_celebrate"
    case invalidPlacement = "invalid_placement"
    case piecePickup = "piece_pickup"
    case hoverCell = "hover_cell"
    case zoneEnter = "zone_enter"
    case zoneExit = "zone_exit"
    case milestone = "milestone"
    case dailyReward = "daily_reward"
    case nearDeath = "near_death"
    case tightFit = "tight_fit"

    var frequency: Double {
        switch self {
        case .placeBlock: return 440
        case .clearLine: return 600
        case .combo2x: return 660
        case .combo3x: return 770
        case .combo4x: return 880
        case .combo5x: return 990
        case .powerUpEarn: return 880
        case .powerUpUse: return 330
        case .gameOver: return 220
        case .highScore: return 1100
        case .buttonTap: return 500
        case .streakCelebrate: return 880
        case .invalidPlacement: return 200
        case .piecePickup: return 550
        case .hoverCell: return 480
        case .zoneEnter: return 1000
        case .zoneExit: return 300
        case .milestone: return 880
        case .dailyReward: return 660
        case .nearDeath: return 150
        case .tightFit: return 700
        }
    }

    var duration: Double {
        switch self {
        case .placeBlock: return 0.05
        case .clearLine: return 0.15
        case .combo2x: return 0.12
        case .combo3x: return 0.15
        case .combo4x: return 0.18
        case .combo5x: return 0.22
        case .powerUpEarn: return 0.2
        case .powerUpUse: return 0.15
        case .gameOver: return 0.4
        case .highScore: return 0.5
        case .buttonTap: return 0.03
        case .streakCelebrate: return 0.3
        case .invalidPlacement: return 0.08
        case .piecePickup: return 0.04
        case .hoverCell: return 0.02
        case .zoneEnter: return 0.35
        case .zoneExit: return 0.25
        case .milestone: return 0.3
        case .dailyReward: return 0.25
        case .nearDeath: return 0.15
        case .tightFit: return 0.08
        }
    }

    var waveform: WaveformType {
        switch self {
        case .placeBlock, .buttonTap, .hoverCell: return .sine
        case .clearLine, .combo2x, .combo3x, .combo4x, .combo5x: return .sweep
        case .powerUpEarn, .highScore, .streakCelebrate: return .chime
        case .powerUpUse: return .explosion
        case .gameOver: return .descending
        case .invalidPlacement: return .buzz
        case .piecePickup: return .sine
        case .zoneEnter: return .chime
        case .zoneExit: return .descending
        case .milestone: return .chime
        case .dailyReward: return .chime
        case .nearDeath: return .buzz
        case .tightFit: return .sine
        }
    }
}

enum WaveformType {
    case sine, sweep, chime, explosion, descending, buzz
}

// MARK: - Audio Manager

final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var sfxEnabled: Bool {
        didSet { UserDefaults.standard.set(sfxEnabled, forKey: "sfxEnabled") }
    }
    @Published var musicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled")
            if musicEnabled { startBackgroundMusic() } else { stopBackgroundMusic() }
        }
    }

    private var audioEngine: AVAudioEngine?
    private var playerNodes: [AVAudioPlayerNode] = []
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var musicPlayer: AVAudioPlayerNode?
    private var musicBuffer: AVAudioPCMBuffer?
    private let logger = Logger(subsystem: "com.gridlock.app", category: "AudioManager")

    private let sampleRate: Double = 44100
    private let maxConcurrentSounds = 8

    private init() {
        sfxEnabled = UserDefaults.standard.object(forKey: "sfxEnabled") as? Bool ?? true
        musicEnabled = UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true
    }

    // MARK: - Setup

    func preloadAll() {
        setupAudioSession()
        setupEngine()
        generateAllBuffers()
        if musicEnabled {
            startBackgroundMusic()
        }
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            logger.error("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    private func setupEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // Create player node pool
        for _ in 0..<maxConcurrentSounds {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            playerNodes.append(node)
        }

        // Music player
        musicPlayer = AVAudioPlayerNode()
        engine.attach(musicPlayer!)
        engine.connect(musicPlayer!, to: engine.mainMixerNode, format: format)
        musicPlayer?.volume = 0.15

        do {
            try engine.start()
            logger.info("Audio engine started")
        } catch {
            logger.error("Audio engine start failed: \(error.localizedDescription)")
        }
    }

    private func generateAllBuffers() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        for effect in SoundEffect.allCases {
            let frameCount = AVAudioFrameCount(effect.duration * sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { continue }
            buffer.frameLength = frameCount

            guard let data = buffer.floatChannelData?[0] else { continue }

            switch effect.waveform {
            case .sine:
                generateSine(data: data, frames: Int(frameCount), frequency: effect.frequency, decay: 0.9)

            case .sweep:
                generateSweep(data: data, frames: Int(frameCount),
                             startFreq: effect.frequency * 0.7,
                             endFreq: effect.frequency * 1.3, decay: 0.85)

            case .chime:
                generateChime(data: data, frames: Int(frameCount), baseFreq: effect.frequency)

            case .explosion:
                generateExplosion(data: data, frames: Int(frameCount))

            case .descending:
                generateSweep(data: data, frames: Int(frameCount),
                             startFreq: effect.frequency * 1.5,
                             endFreq: effect.frequency * 0.5, decay: 0.8)

            case .buzz:
                generateBuzz(data: data, frames: Int(frameCount), frequency: effect.frequency)
            }

            buffers[effect] = buffer
        }

        // Generate ambient music buffer
        generateMusicBuffer()

        logger.info("Generated \(self.buffers.count) sound buffers")
    }

    // MARK: - Waveform Generators

    private func generateSine(data: UnsafeMutablePointer<Float>, frames: Int, frequency: Double, decay: Double) {
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let envelope = pow(decay, t * 20) * (1.0 - pow(Double(i) / Double(frames), 2))
            data[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.5)
        }
    }

    private func generateSweep(data: UnsafeMutablePointer<Float>, frames: Int,
                                startFreq: Double, endFreq: Double, decay: Double) {
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frames)
            let freq = startFreq + (endFreq - startFreq) * progress
            let envelope = pow(decay, t * 15) * (1.0 - progress * progress)
            data[i] = Float(sin(2.0 * .pi * freq * t) * envelope * 0.4)
        }
    }

    private func generateChime(data: UnsafeMutablePointer<Float>, frames: Int, baseFreq: Double) {
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frames)
            let envelope = (1.0 - progress) * (1.0 - progress)
            let v1 = sin(2.0 * .pi * baseFreq * t) * 0.3
            let v2 = sin(2.0 * .pi * baseFreq * 1.5 * t) * 0.2
            let v3 = sin(2.0 * .pi * baseFreq * 2.0 * t) * 0.1
            data[i] = Float((v1 + v2 + v3) * envelope)
        }
    }

    private func generateExplosion(data: UnsafeMutablePointer<Float>, frames: Int) {
        for i in 0..<frames {
            let progress = Double(i) / Double(frames)
            let envelope = (1.0 - progress) * (1.0 - progress)
            let noise = Double.random(in: -1...1)
            let lowFreq = sin(2.0 * .pi * 80 * Double(i) / sampleRate)
            data[i] = Float((noise * 0.3 + lowFreq * 0.3) * envelope)
        }
    }

    private func generateBuzz(data: UnsafeMutablePointer<Float>, frames: Int, frequency: Double) {
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frames)
            let envelope = (1.0 - progress)
            let square = sin(2.0 * .pi * frequency * t) > 0 ? 0.3 : -0.3
            data[i] = Float(square * envelope)
        }
    }

    private func generateMusicBuffer() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let duration = 8.0 // 8-second loop
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return }

        // Gentle ambient pad: layered sine waves with slow modulation
        let chords: [(Double, Double)] = [
            (220, 0.08), (277.18, 0.06), (329.63, 0.05), (440, 0.03)
        ]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = 0.0
            for (freq, amp) in chords {
                let vibrato = 1.0 + sin(2.0 * .pi * 0.5 * t) * 0.002
                sample += sin(2.0 * .pi * freq * vibrato * t) * amp
            }
            // Fade in/out at loop boundaries
            let fadeFrames = Int(sampleRate * 0.5)
            var fade = 1.0
            if i < fadeFrames {
                fade = Double(i) / Double(fadeFrames)
            } else if i > Int(frameCount) - fadeFrames {
                fade = Double(Int(frameCount) - i) / Double(fadeFrames)
            }
            data[i] = Float(sample * fade)
        }

        musicBuffer = buffer
    }

    // MARK: - Playback

    func play(_ effect: SoundEffect) {
        guard sfxEnabled, let buffer = buffers[effect] else { return }

        // Find available player node
        guard let player = playerNodes.first(where: { !$0.isPlaying }) ?? playerNodes.first else { return }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    func playComboSound(level: Int) {
        switch min(level, 5) {
        case 2: play(.combo2x)
        case 3: play(.combo3x)
        case 4: play(.combo4x)
        case 5: play(.combo5x)
        default: break
        }
    }

    func startBackgroundMusic() {
        guard musicEnabled, let player = musicPlayer, let buffer = musicBuffer else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    func stopBackgroundMusic() {
        musicPlayer?.stop()
    }

    /// Briefly duck music volume for important SFX
    func duckMusic(duration: TimeInterval = 0.3) {
        guard let player = musicPlayer, player.isPlaying else { return }
        player.volume = 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            player.volume = 0.15
        }
    }
}

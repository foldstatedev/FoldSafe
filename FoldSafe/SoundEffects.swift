import AVFAudio
import os

/// The game's sounds, synthesised in code at launch, so there are no audio files.
///
/// - A dial click each time the hinge turns the dial one mark (3° of hinge). The
///   click rises in pitch as the hinge nears the target.
/// - A chime when the hinge enters the target.
/// - A rising tone while the player holds, cut off if they leave.
/// - A bolt, a latch and a bright chord as the door opens.
final class SoundEffects {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)
    private var clickPlayers: [AVAudioPlayerNode] = []
    private let chimePlayer = AVAudioPlayerNode()
    private let holdPlayer = AVAudioPlayerNode()
    private let unlockPlayer = AVAudioPlayerNode()

    private var clicks: [AVAudioPCMBuffer] = []
    private var chimeSound: AVAudioPCMBuffer?
    private var holdSound: AVAudioPCMBuffer?
    private var unlockSound: AVAudioPCMBuffer?
    private var finaleSound: AVAudioPCMBuffer?

    private var nextClickPlayer = 0
    private var lastClick = Date.distantPast
    private var isReady = false
    private var isStarting = false
    private let log = Logger(subsystem: "dev.foldstate.FoldSafe", category: "sound")

    /// Builds the sounds and starts the audio engine. Safe to call more than once.
    func start() async {
        guard !isReady, !isStarting, let format else { return }
        isStarting = true
        defer { isStarting = false }

        let session = AVAudioSession.sharedInstance()
        do {
            // Playback, so the sounds are heard on camera even with the phone on
            // silent; mixed, so it never stops other audio.
            try session.setCategory(.playback, options: [.mixWithOthers])
            // Activation can be slow, so it runs asynchronously instead of
            // blocking the main thread (the synchronous call is a hang risk).
            _ = try await session.activate(options: [])
        } catch {
            log.error("Audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }

        // Eight click pitches, from 700 Hz far away up to about 2.4 kHz at the target.
        clicks = (0..<8).compactMap { step in
            Synth.click(frequency: 700 * pow(2, Double(step) / 4), format: format)
        }
        chimeSound = Synth.chime(format: format)
        holdSound = Synth.rise(duration: GameConfig.holdDuration, format: format)
        unlockSound = Synth.unlock(isFinale: false, format: format)
        finaleSound = Synth.unlock(isFinale: true, format: format)

        clickPlayers = (0..<4).map { _ in AVAudioPlayerNode() }
        do {
            for player in clickPlayers + [chimePlayer, holdPlayer, unlockPlayer] {
                engine.attach(player)
                try engine.connectNode(player, to: engine.mainMixerNode, format: format)
            }
            try engine.start()
            isReady = true
            log.notice("Sound ready")
        } catch {
            log.error("Audio engine setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// One dial click. `closeness` runs from 0 (far away) to 1 (on target) and sets the pitch.
    func click(closeness: Double) {
        guard isReady, !clicks.isEmpty else { return }
        // A fast sweep crosses many marks at once; cap it at about 30 clicks a second.
        let now = Date.now
        guard now.timeIntervalSince(lastClick) > 0.033 else { return }
        lastClick = now

        let step = Int((min(max(closeness, 0), 1) * Double(clicks.count - 1)).rounded())
        play(clicks[step], on: clickPlayers[nextClickPlayer])
        nextClickPlayer = (nextClickPlayer + 1) % clickPlayers.count
    }

    func chime() {
        play(chimeSound, on: chimePlayer)
    }

    func startHold() {
        play(holdSound, on: holdPlayer)
    }

    func stopHold() {
        holdPlayer.stop()
    }

    func unlock(isFinale: Bool) {
        holdPlayer.stop()
        play(isFinale ? finaleSound : unlockSound, on: unlockPlayer)
    }

    private func play(_ buffer: AVAudioPCMBuffer?, on player: AVAudioPlayerNode) {
        guard isReady, let buffer else { return }
        if !engine.isRunning {
            // The engine stops when the audio route changes; restart it quietly.
            do { try engine.start() } catch { return }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        guard !player.isPlaying else { return }
        do {
            try player.playAudio()
        } catch {
            log.error("Sound failed to play: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// A tiny synthesiser: every sound is a few decaying sine waves and a little noise.
private enum Synth {
    static let sampleRate = 44_100.0

    /// A short metallic click, like a dial detent.
    static func click(frequency: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        var noise = Noise()
        return render(duration: 0.05, format: format) { t in
            let ring = sin(2 * .pi * frequency * t) * 0.55 + sin(2 * .pi * frequency * 2.76 * t) * 0.25
            let snap = noise.next() * exp(-t / 0.0015) * 0.5
            return (ring * exp(-t / 0.009) + snap) * 0.6
        }
    }

    /// A small bell for landing in the green.
    static func chime(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let partials: [(frequency: Double, level: Double, decay: Double)] = [
            (1568, 0.30, 0.45), (2349, 0.18, 0.30), (3136, 0.10, 0.20),
        ]
        return render(duration: 1.0, format: format) { t in
            let attack = min(t / 0.004, 1)
            let bell = partials.reduce(0) { sum, partial in
                sum + sin(2 * .pi * partial.frequency * t) * partial.level * exp(-t / partial.decay)
            }
            return attack * bell
        }
    }

    /// An octave glide that swells as the green ring fills.
    static func rise(duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let low = 330.0
        let high = 660.0
        let rate = log(high / low) / duration
        return render(duration: duration, format: format) { t in
            // Phase of a tone gliding exponentially from `low` to `high`.
            let phase = 2 * .pi * low * (exp(rate * t) - 1) / rate
            let progress = t / duration
            let swell = 0.06 + 0.22 * progress * progress
            let fadeIn = min(t / 0.02, 1)
            return (sin(phase) + 0.3 * sin(2 * phase)) * swell * fadeIn
        }
    }

    /// The bolt, two latch clicks as the handle turns, then a chord as the door swings.
    /// The timings match the unlock animation in SafeView.
    static func unlock(isFinale: Bool, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        var noise = Noise()
        let chord: [Double] = isFinale ? [784, 1047, 1319, 1568, 2093, 2637] : [1047, 1319, 1568, 2093]
        let chordStart = 0.7
        let chordDecay = isFinale ? 1.1 : 0.8
        return render(duration: isFinale ? 3.2 : 2.4, format: format) { t in
            // Bolt: a low thump dropping in pitch, with a burst of grit.
            let thumpFrequency = 55 + 45 * exp(-t / 0.05)
            var sample = sin(2 * .pi * thumpFrequency * t) * exp(-t / 0.12) * 0.9
            sample += noise.next() * exp(-t / 0.018) * 0.35

            // Latch: two sharp clicks as the handle turns.
            for click in [0.26, 0.34] where t >= click {
                let u = t - click
                sample += (sin(2 * .pi * 1900 * u) * 0.5 + noise.next() * 0.3) * exp(-u / 0.006) * 0.8
            }

            // Door: a bright chord, one note after another.
            for (index, frequency) in chord.enumerated() {
                let start = chordStart + Double(index) * 0.045
                guard t >= start else { continue }
                let u = t - start
                let attack = min(u / 0.006, 1)
                let note = sin(2 * .pi * frequency * u) + 0.25 * sin(2 * .pi * frequency * 2 * u)
                sample += attack * note * exp(-u / chordDecay) * 0.16
            }
            return sample
        }
    }

    /// Fills a buffer by sampling `wave` at each moment, soft-clipped so nothing distorts.
    private static func render(duration: Double, format: AVAudioFormat,
                               wave: (Double) -> Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            channel[frame] = Float(tanh(wave(Double(frame) / sampleRate)))
        }
        return buffer
    }
}

/// Cheap repeatable white noise (xorshift).
private struct Noise {
    private var state: UInt32 = 0x9E37_79B9

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return Double(state) / Double(UInt32.max) * 2 - 1
    }
}

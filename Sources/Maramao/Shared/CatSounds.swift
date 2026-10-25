import AVFoundation
import Foundation
import MaramaoCore

/// Plays the cat sounds synthesized by `CatVoice`: meows, purrs, a "mrrp"
/// and the gentle "break over" chime. No audio files: every sound is
/// rendered once into a PCM buffer and cached.
///
/// Respects `AppSettings.soundEnabled` and `soundVolume`. The audio engine
/// starts lazily on the first sound, stops itself when idle, is rebuilt after
/// an audio configuration change (headphones, new output device), and simply
/// stays quiet when the Mac has no audio output.
///
/// Use it from the main thread; calls from elsewhere hop to main.
final class CatSounds {
    static let shared = CatSounds()

    enum Sound: Hashable {
        case meow(MeowVariant)
        /// A purr, its length in tenths of a second (so buffers can be cached).
        case purr(tenths: Int)
        case chirp
        case chime
    }

    private let settings: AppSettings
    private let sampleRate = CatVoice.defaultSampleRate
    private let format: AVAudioFormat?
    private let poolSize = 4

    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var purrPlayerIndex: Int?
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var configurationObserver: NSObjectProtocol?
    private var idleStop: DispatchWorkItem?
    private var busyUntil = Date.distantPast
    /// After a failed start (no output device), wait a bit before trying again.
    private var retryAfter = Date.distantPast
    private var meowRotation = 0

    init(settings: AppSettings = .shared) {
        self.settings = settings
        format = AVAudioFormat(standardFormatWithSampleRate: CatVoice.defaultSampleRate, channels: 1)
    }

    deinit {
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    func meow(_ variant: MeowVariant = .normal) {
        play(.meow(variant))
    }

    /// A meow picked at random among the friendly ones.
    func randomMeow() {
        let options: [MeowVariant] = [.normal, .cute, .demanding, .questioning]
        meow(options.randomElement() ?? .normal)
    }

    /// Every meow in turn: handy for the "try the sounds" button.
    func nextMeow() {
        let all = MeowVariant.allCases
        let variant = all[meowRotation % all.count]
        meowRotation += 1
        meow(variant)
    }

    /// Purrs for about `duration` seconds. A new purr replaces the previous one.
    func purr(duration: TimeInterval = 2.5) {
        let clamped = min(30, max(0.5, duration.isFinite ? duration : 2.5))
        // Round to half a second so a handful of buffers cover every call.
        let tenths = Int((clamped * 2).rounded()) * 5
        play(.purr(tenths: tenths), gain: 0.9)
    }

    /// A short trilled "mrrp".
    func chirp() {
        play(.chirp)
    }

    /// Two soft tones: the break is over.
    func breakOverChime() {
        play(.chime, gain: 0.7)
    }

    func stopAll() {
        onMain { [self] in
            for player in players {
                player.stop()
            }
            purrPlayerIndex = nil
        }
    }

    // MARK: - Playback

    func play(_ sound: Sound, gain: Float = 1) {
        onMain { [self] in
            guard settings.soundEnabled, FocusFilterState.shared.policy.soundsAllowed else { return }
            let volume = Float(min(1, max(0, settings.soundVolume))) * gain
            guard volume > 0.001 else { return }
            guard let buffer = buffer(for: sound) else { return }
            guard let engine = readyEngine(), engine.isRunning, !players.isEmpty else { return }

            let index = playerIndex(for: sound)
            let player = players[index]
            player.stop()
            player.volume = volume
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            // play() raises an Objective-C exception if the engine is not running.
            guard engine.isRunning else { return }
            player.play()

            let length = Double(buffer.frameLength) / sampleRate
            busyUntil = max(busyUntil, Date().addingTimeInterval(length))
            scheduleIdleStop()
        }
    }

    private func playerIndex(for sound: Sound) -> Int {
        if case .purr = sound {
            // Purrs reuse their own voice, so petting the cat never stacks them.
            if let index = purrPlayerIndex, index < players.count { return index }
            let index = takeNextPlayer()
            purrPlayerIndex = index
            return index
        }
        var index = takeNextPlayer()
        if index == purrPlayerIndex {
            index = takeNextPlayer()
        }
        return index
    }

    private func takeNextPlayer() -> Int {
        let index = nextPlayer % max(1, players.count)
        nextPlayer = (nextPlayer + 1) % max(1, players.count)
        return index
    }

    // MARK: - Buffers

    private func buffer(for sound: Sound) -> AVAudioPCMBuffer? {
        if let cached = buffers[sound] { return cached }
        guard let format else { return nil }
        let samples = render(sound)
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        for i in 0..<samples.count {
            channel[i] = samples[i]
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)

        if case .purr = sound {
            // Keep only a few purr lengths around.
            let purrKeys = buffers.keys.filter { key in
                if case .purr = key { return true }
                return false
            }
            if purrKeys.count >= 6 {
                for key in purrKeys { buffers[key] = nil }
            }
        }
        buffers[sound] = buffer
        return buffer
    }

    private func render(_ sound: Sound) -> [Float] {
        switch sound {
        case .meow(let variant):
            return CatVoice.renderMeow(sampleRate: sampleRate, variant: variant, seed: UInt64.random(in: 1...1_000_000))
        case .purr(let tenths):
            return CatVoice.renderPurr(sampleRate: sampleRate, duration: Double(tenths) / 10)
        case .chirp:
            return CatVoice.renderChirp(sampleRate: sampleRate)
        case .chime:
            return CatVoice.renderChime(sampleRate: sampleRate)
        }
    }

    // MARK: - Engine

    /// The running engine, starting (or building) it if needed. Nil when there
    /// is no usable audio output.
    private func readyEngine() -> AVAudioEngine? {
        if let engine {
            if engine.isRunning { return engine }
            do {
                try engine.start()
                return engine
            } catch {
                tearDown()
            }
        }
        guard Date() >= retryAfter, let format else { return nil }

        let engine = AVAudioEngine()
        // Without an output device the output format is empty, and wiring nodes
        // to it would raise an exception. Stay quiet instead.
        let output = engine.outputNode.outputFormat(forBus: 0)
        guard output.channelCount > 0, output.sampleRate > 0 else {
            retryAfter = Date().addingTimeInterval(10)
            return nil
        }

        var pool: [AVAudioPlayerNode] = []
        for _ in 0..<poolSize {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            pool.append(player)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            retryAfter = Date().addingTimeInterval(10)
            return nil
        }

        self.engine = engine
        players = pool
        nextPlayer = 0
        purrPlayerIndex = nil
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            // The output changed (headphones, another device): the engine has
            // stopped. Rebuild it from scratch on the next sound.
            self?.tearDown()
        }
        return engine
    }

    private func tearDown() {
        idleStop?.cancel()
        idleStop = nil
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationObserver = nil
        }
        for player in players {
            player.stop()
        }
        engine?.stop()
        engine = nil
        players = []
        nextPlayer = 0
        purrPlayerIndex = nil
    }

    /// Stops the engine a few seconds after the last sound, so an idle app
    /// does not keep the audio hardware awake.
    private func scheduleIdleStop() {
        idleStop?.cancel()
        let delay = max(0, busyUntil.timeIntervalSinceNow) + 5
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.busyUntil.timeIntervalSinceNow > 0 {
                self.scheduleIdleStop()
                return
            }
            for player in self.players {
                player.stop()
            }
            self.purrPlayerIndex = nil
            self.engine?.stop()
        }
        idleStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

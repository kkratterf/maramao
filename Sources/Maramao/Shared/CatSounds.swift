import AVFoundation
import Foundation
import MaramaoCore

/// Plays the cats' voices: meows, little mews, growls and purrs recorded from real cats
/// (CC0, bundled by `scripts/fetch-cat-sounds.sh`, see `Resources/cat-sounds.tsv`), and
/// the gentle "break over" chime. A build without the recordings (`swift run`) falls back
/// to the voices synthesized by `CatVoice`. Every sound is decoded or rendered once into
/// a PCM buffer and cached.
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
        case hiss
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
    private var angryRotation = 0

    /// The recordings bundled with the app, by kind. Loaded on the first sound.
    private enum Recording: String, CaseIterable {
        /// Friendly meows.
        case meow
        /// Short little meows: pokes, chirps, kittens.
        case mew
        /// Growls and yowls: a cat woken up or shaken.
        case angry
        /// One long purr, cut or looped to length.
        case purr
    }

    private lazy var recordings: [Recording: [AVAudioPCMBuffer]] = loadRecordings()
    /// Every recording of a kind once before any repeats, never twice in a row.
    private var recordingBags: [Recording: ShuffleBag] = [:]

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

    /// An angry hiss: someone woke the cat up.
    func hiss() {
        play(.hiss)
    }

    /// A cat that did not want to be woken: a hiss or a grumpy, rough meow, in turn.
    func angry() {
        angryRotation += 1
        if angryRotation % 2 == 1 {
            hiss()
        } else {
            meow(.grumpy)
        }
    }

    /// Any of the cat's friendly noises, for a cat being poked: meows, a "mrrp", or a purr.
    func randomPoke() {
        switch Int.random(in: 0..<6) {
        case 0: chirp()
        case 1: purr(duration: 1)
        default: randomMeow()
        }
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
        if let recorded = recordedBuffer(for: sound) { return recorded }
        if let cached = buffers[sound] { return cached }
        guard let format else { return nil }
        let samples = render(sound)
        return store(samples, as: sound, format: format)
    }

    /// Caches samples as the buffer for `sound`.
    private func store(_ samples: [Float], as sound: Sound, format: AVAudioFormat) -> AVAudioPCMBuffer? {
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

    // MARK: - Recordings

    /// A real cat for this sound, or nil when the app has no recording of that kind.
    private func recordedBuffer(for sound: Sound) -> AVAudioPCMBuffer? {
        switch sound {
        case .hiss, .meow(.grumpy):
            return nextRecording(.angry)
        case .chirp, .meow(.cute):
            return nextRecording(.mew)
        case .meow:
            return nextRecording(.meow)
        case .purr(let tenths):
            return recordedPurr(tenths: tenths)
        case .chime:
            return nil
        }
    }

    private func nextRecording(_ kind: Recording) -> AVAudioPCMBuffer? {
        let all = recordings[kind] ?? []
        guard !all.isEmpty else { return nil }
        var bag = recordingBags[kind] ?? ShuffleBag(count: all.count)
        let index = bag.next() ?? 0
        recordingBags[kind] = bag
        return all[min(index, all.count - 1)]
    }

    /// The recorded purr, cut to `tenths` of a second (or looped without a gap when it is
    /// shorter), with a soft fade at the end. Cached like the synthesized purrs.
    private func recordedPurr(tenths: Int) -> AVAudioPCMBuffer? {
        guard let source = recordings[.purr]?.first,
              let input = source.floatChannelData?[0],
              let format
        else { return nil }
        let key = Sound.purr(tenths: tenths)
        if let cached = buffers[key] { return cached }
        let sourceCount = Int(source.frameLength)
        guard sourceCount > 0 else { return nil }
        let count = max(1, Int(Double(tenths) / 10 * sampleRate))
        var samples = CatRecording.looped(
            Array(UnsafeBufferPointer(start: input, count: sourceCount)),
            count: count,
            crossfade: Int(0.25 * sampleRate)
        )
        let fade = min(count, Int(0.3 * sampleRate))
        for i in 0..<fade {
            samples[count - 1 - i] *= Float(i) / Float(fade)
        }
        return store(samples, as: key, format: format)
    }

    private func loadRecordings() -> [Recording: [AVAudioPCMBuffer]] {
        guard let format,
              let root = Bundle.main.resourceURL?.appendingPathComponent("CatSounds", isDirectory: true)
        else { return [:] }
        var result: [Recording: [AVAudioPCMBuffer]] = [:]
        for kind in Recording.allCases {
            let folder = root.appendingPathComponent(kind.rawValue, isDirectory: true)
            guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
            let audio = files
                .filter { ["m4a", "caf", "wav", "aiff", "mp3"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            let target = kind == .purr ? CatRecording.purrLoudness : CatRecording.voiceLoudness
            let loaded = audio.compactMap { Self.decode($0, to: format, target: target) }
            if !loaded.isEmpty {
                result[kind] = loaded
            }
        }
        return result
    }

    /// Reads an audio file into a buffer in the players' format (mono, 44.1 kHz), without
    /// the silence around the cat, at `target` loudness and with a few milliseconds of
    /// fade at both ends, so a recording starts at once, sits with the others and never
    /// clicks.
    private static func decode(_ url: URL, to format: AVAudioFormat, target: Float) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let source = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: frames) else { return nil }
        do {
            try file.read(into: input)
        } catch {
            return nil
        }

        let output: AVAudioPCMBuffer
        if source == format {
            output = input
        } else {
            guard let converter = AVAudioConverter(from: source, to: format) else { return nil }
            converter.downmix = true
            let ratio = format.sampleRate / source.sampleRate
            let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 4096
            guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
            var delivered = false
            var error: NSError?
            let status = converter.convert(to: converted, error: &error) { _, inputStatus in
                if delivered {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                delivered = true
                inputStatus.pointee = .haveData
                return input
            }
            guard status != .error else { return nil }
            output = converted
        }

        let count = Int(output.frameLength)
        guard count > 0, let decoded = output.floatChannelData?[0] else { return nil }
        let rate = format.sampleRate
        var samples = Array(UnsafeBufferPointer(start: decoded, count: count))
        samples = CatRecording.trimmed(samples, sampleRate: rate)
        samples = CatRecording.leveled(samples, sampleRate: rate, target: target)
        samples = CatRecording.faded(samples, sampleRate: rate)
        guard !samples.isEmpty,
              let prepared = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = prepared.floatChannelData?[0]
        else { return nil }
        for i in 0..<samples.count {
            channel[i] = samples[i]
        }
        prepared.frameLength = AVAudioFrameCount(samples.count)
        return prepared
    }

    // MARK: - Synthesis

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
        case .hiss:
            return CatVoice.renderHiss(sampleRate: sampleRate, seed: UInt64.random(in: 1...1_000_000))
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

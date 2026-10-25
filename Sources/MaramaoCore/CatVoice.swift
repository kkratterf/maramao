import Foundation

/// The kinds of meow `CatVoice` can synthesize.
public enum MeowVariant: String, CaseIterable, Sendable {
    /// A kitten: short and high.
    case cute
    /// The classic "mi-aaa-oww".
    case normal
    /// "MIAAAO": long, loud and insistent. Usually means food.
    case demanding
    /// "Mrrp?": starts closed and trilled, ends on a rising question.
    case questioning
    /// A grumpy old tom: low, rough and long.
    case grumpy
}

/// Procedural cat sounds. Every function is pure: same arguments, same
/// samples, no audio APIs. The app turns the result into audio buffers.
///
/// The meow is a small formant synthesizer: a band-limited sawtooth (the
/// "vocal folds") with vibrato and jitter goes through three resonant
/// band-pass filters (the "mouth") whose frequencies glide from an "i" to
/// an "a" to an "u/o", so the cat says "mi-aaa-oww".
public enum CatVoice {
    public static let defaultSampleRate: Double = 44_100

    /// Length of a meow, in seconds.
    public static func duration(of variant: MeowVariant) -> Double {
        MeowRecipe.recipe(for: variant).duration
    }

    /// Length of the trilled "mrrp", in seconds.
    public static let chirpDuration: Double = 0.32
    /// Length of the "break over" chime, in seconds.
    public static let chimeDuration: Double = 1.6

    // MARK: - Meow

    public static func renderMeow(
        sampleRate: Double = defaultSampleRate,
        variant: MeowVariant,
        seed: UInt64 = 1
    ) -> [Float] {
        let recipe = MeowRecipe.recipe(for: variant)
        let count = sampleCount(sampleRate, recipe.duration)
        guard count > 0 else { return [] }

        var rng = SplitMix64(seed: seed)
        var output = [Double](repeating: 0, count: count)
        var formants = [Biquad(), Biquad(), Biquad()]
        let gains = formantGains
        var phase = 0.0
        var jitter = 0.0
        let attack = 0.03
        let release = 0.12
        let last = Double(max(1, count - 1))

        for i in 0..<count {
            let t = Double(i) / sampleRate
            let u = Double(i) / last
            let f0 = Keyframes.value(recipe.pitch, at: u, index: 0)

            if i % filterUpdateInterval == 0 {
                configureFormants(&formants, keys: recipe.formants, at: u, f0: f0, sampleRate: sampleRate)
                // Slow random walk: the pitch is never perfectly steady.
                jitter = jitter * 0.9 + rng.bipolar() * recipe.jitter * 0.45
            }

            let vibrato = recipe.vibratoDepth * sin(2 * Double.pi * recipe.vibratoRate * t)
            let frequency = f0 * (1 + vibrato + jitter)
            let source = sawtooth(phase: &phase, frequency: frequency, sampleRate: sampleRate)
                + rng.bipolar() * recipe.breath

            var y = 0.0
            for k in 0..<formants.count {
                y += gains[k] * formants[k].process(source)
            }

            var envelope = Keyframes.value(recipe.amplitude, at: u, index: 0)
            envelope *= smoothstep(t / attack) * smoothstep((recipe.duration - t) / release)
            if recipe.trillDepth > 0 && u < recipe.trillUntil {
                let fade = 1 - u / recipe.trillUntil
                let wobble = 0.5 + 0.5 * cos(2 * Double.pi * recipe.trillRate * t)
                envelope *= 1 - recipe.trillDepth * fade * wobble
            }
            output[i] = y * envelope
        }
        return finish(output, peak: 0.85)
    }

    // MARK: - Purr

    /// A purr: low-passed noise and a ~50 Hz rumble, both pulsing ~25 times a
    /// second, breathing out (louder) and in (softer) about twice a second.
    public static func renderPurr(
        sampleRate: Double = defaultSampleRate,
        duration: Double,
        seed: UInt64 = 1
    ) -> [Float] {
        let count = sampleCount(sampleRate, duration)
        guard count > 0 else { return [] }

        var rng = SplitMix64(seed: seed)
        var lowPass1 = Biquad()
        var lowPass2 = Biquad()
        lowPass1.setLowPass(frequency: 400, q: 0.707, sampleRate: sampleRate)
        lowPass2.setLowPass(frequency: 400, q: 0.707, sampleRate: sampleRate)
        var output = [Double](repeating: 0, count: count)
        let breathPeriod = 1.0
        let exhaleShare = 0.55
        let fade = min(0.35, duration * 0.25)
        var flutterPhase = 0.0
        var rumblePhase = 0.0

        for i in 0..<count {
            let t = Double(i) / sampleRate
            let cycle = t.truncatingRemainder(dividingBy: breathPeriod) / breathPeriod
            let local: Double
            let level: Double
            let rate: Double
            if cycle < exhaleShare {
                local = cycle / exhaleShare
                level = 1.0
                rate = 24
            } else {
                local = (cycle - exhaleShare) / (1 - exhaleShare)
                level = 0.6
                rate = 27
            }
            // A short dip at each turn of the breath.
            let shape = max(0, sin(Double.pi * local)).squareRoot()

            flutterPhase += rate / sampleRate
            if flutterPhase >= 1 { flutterPhase -= 1 }
            let raised = 0.5 - 0.5 * cos(2 * Double.pi * flutterPhase)
            let pulse = raised * raised * raised

            rumblePhase += 2 * rate / sampleRate
            if rumblePhase >= 1 { rumblePhase -= 1 }
            let rumble = sin(2 * Double.pi * rumblePhase)

            let x = (rng.bipolar() * 0.8 + rumble * 0.5) * (0.15 + 0.85 * pulse)
            let y = lowPass2.process(lowPass1.process(x))
            let envelope = level * shape * smoothstep(t / fade) * smoothstep((duration - t) / fade)
            output[i] = y * envelope
        }
        return finish(output, peak: 0.8)
    }

    // MARK: - Chirp

    /// A short trilled "mrrp": a closed "m" opening up, a rolled "r", a quick rise.
    public static func renderChirp(sampleRate: Double = defaultSampleRate, seed: UInt64 = 1) -> [Float] {
        let duration = chirpDuration
        let count = sampleCount(sampleRate, duration)
        guard count > 0 else { return [] }

        var rng = SplitMix64(seed: seed)
        var formants = [Biquad(), Biquad(), Biquad()]
        let gains = formantGains
        let pitch: [Keyframe] = [Keyframe(0, 520), Keyframe(0.5, 640), Keyframe(1, 820)]
        let vowels: [Keyframe] = [Vowel.m.at(0), Vowel.u.at(0.45), Vowel.a.at(1)]
        var output = [Double](repeating: 0, count: count)
        var phase = 0.0
        let last = Double(max(1, count - 1))

        for i in 0..<count {
            let t = Double(i) / sampleRate
            let u = Double(i) / last
            let f0 = Keyframes.value(pitch, at: u, index: 0)
            if i % filterUpdateInterval == 0 {
                configureFormants(&formants, keys: vowels, at: u, f0: f0, sampleRate: sampleRate)
            }
            let source = sawtooth(phase: &phase, frequency: f0, sampleRate: sampleRate) + rng.bipolar() * 0.05
            var y = 0.0
            for k in 0..<formants.count {
                y += gains[k] * formants[k].process(source)
            }
            let wobble = 0.5 + 0.5 * cos(2 * Double.pi * 30 * t)
            let trill = 1 - 0.8 * wobble * (1 - smoothstep(u / 0.7))
            let envelope = smoothstep(t / 0.02) * smoothstep((duration - t) / 0.08) * trill
            output[i] = y * envelope
        }
        return finish(output, peak: 0.8)
    }

    // MARK: - Chime

    /// A gentle "break over" chime: two soft sine tones, G5 then C6.
    public static func renderChime(sampleRate: Double = defaultSampleRate) -> [Float] {
        let duration = chimeDuration
        let count = sampleCount(sampleRate, duration)
        guard count > 0 else { return [] }

        let notes: [(start: Double, frequency: Double)] = [(0, 783.99), (0.18, 1046.50)]
        var output = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var y = 0.0
            for note in notes {
                let local = t - note.start
                if local < 0 { continue }
                let envelope = smoothstep(local / 0.012) * exp(-local * 3.2)
                let w = 2 * Double.pi * note.frequency * local
                y += envelope * (sin(w) + 0.12 * sin(2 * w))
            }
            output[i] = y * smoothstep((duration - t) / 0.2)
        }
        return finish(output, peak: 0.6)
    }

    // MARK: - Building blocks

    /// Formant filter coefficients are recomputed every this many samples.
    static let filterUpdateInterval = 32
    /// Relative loudness of the three formants.
    static let formantGains: [Double] = [1.0, 2.2, 0.9]

    static func sampleCount(_ sampleRate: Double, _ duration: Double) -> Int {
        guard sampleRate.isFinite, duration.isFinite, sampleRate > 0, duration > 0 else { return 0 }
        return Int(duration * sampleRate)
    }

    static func smoothstep(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }

    /// Band-limited sawtooth (PolyBLEP), advancing `phase` by one sample.
    static func sawtooth(phase: inout Double, frequency: Double, sampleRate: Double) -> Double {
        let dt = min(0.5, max(0, frequency / sampleRate))
        phase += dt
        if phase >= 1 { phase -= 1 }
        return 2 * phase - 1 - polyBLEP(phase, dt)
    }

    static func polyBLEP(_ phase: Double, _ dt: Double) -> Double {
        guard dt > 0 else { return 0 }
        if phase < dt {
            let x = phase / dt
            return x + x - x * x - 1
        }
        if phase > 1 - dt {
            let x = (phase - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    /// Points the three band-pass filters at the formants of the vowel at `u`.
    /// Bands widen with the pitch, so the sparse harmonics of a high voice
    /// still reach the resonances.
    static func configureFormants(_ filters: inout [Biquad], keys: [Keyframe], at u: Double, f0: Double, sampleRate: Double) {
        let spread = max(80, f0 * 0.6)
        let widths = [spread, spread * 1.3, spread * 1.8]
        for k in 0..<filters.count {
            let frequency = Keyframes.value(keys, at: u, index: k)
            filters[k].setBandPass(frequency: frequency, bandwidth: widths[k], sampleRate: sampleRate)
        }
    }

    /// Normalizes to `peak`, clamps to [-1, 1] and drops any non-finite sample.
    static func finish(_ samples: [Double], peak target: Double) -> [Float] {
        var peak = 0.0
        for x in samples where x.isFinite {
            peak = max(peak, abs(x))
        }
        let gain = peak > 1e-9 ? target / peak : 0
        return samples.map { x -> Float in
            guard x.isFinite else { return 0 }
            return Float(min(1, max(-1, x * gain)))
        }
    }
}

// MARK: - Recipes

/// A point on a curve over normalized time 0...1.
struct Keyframe {
    var t: Double
    var values: [Double]

    init(_ t: Double, _ values: Double...) {
        self.t = t
        self.values = values
    }

    init(t: Double, values: [Double]) {
        self.t = t
        self.values = values
    }
}

enum Keyframes {
    /// Value `index` of the curve at `t`, eased with smoothstep between keys.
    static func value(_ keys: [Keyframe], at t: Double, index: Int) -> Double {
        guard let first = keys.first else { return 0 }
        if t <= first.t { return first.values[index] }
        for k in 1..<keys.count {
            let a = keys[k - 1]
            let b = keys[k]
            if t <= b.t {
                let span = b.t - a.t
                let x = span > 0 ? CatVoice.smoothstep((t - a.t) / span) : 1
                return a.values[index] + (b.values[index] - a.values[index]) * x
            }
        }
        return keys[keys.count - 1].values[index]
    }
}

/// Formant frequencies (F1, F2, F3) of the vowels a cat uses.
enum Vowel {
    case i, a, u, m

    var formants: [Double] {
        switch self {
        case .i: return [300, 2300, 3200]
        case .a: return [800, 1200, 2800]
        case .u: return [400, 800, 2600]
        case .m: return [250, 1000, 2500]
        }
    }

    func at(_ t: Double) -> Keyframe {
        Keyframe(t: t, values: formants)
    }
}

struct MeowRecipe {
    var duration: Double
    var pitch: [Keyframe]
    var formants: [Keyframe]
    var amplitude: [Keyframe]
    var vibratoRate: Double
    var vibratoDepth: Double
    var jitter: Double
    var trillRate: Double = 0
    var trillDepth: Double = 0
    var trillUntil: Double = 0
    var breath: Double

    static func recipe(for variant: MeowVariant) -> MeowRecipe {
        switch variant {
        case .cute:
            return MeowRecipe(
                duration: 0.55,
                pitch: [Keyframe(0, 750), Keyframe(0.3, 1150), Keyframe(0.7, 1050), Keyframe(1, 850)],
                formants: [Vowel.i.at(0), Vowel.a.at(0.35), Vowel.a.at(0.75), Vowel.u.at(1)],
                amplitude: [Keyframe(0, 0.5), Keyframe(0.25, 1), Keyframe(0.7, 0.9), Keyframe(1, 0.5)],
                vibratoRate: 6, vibratoDepth: 0.012, jitter: 0.004, breath: 0.04
            )
        case .normal:
            return MeowRecipe(
                duration: 0.8,
                pitch: [Keyframe(0, 500), Keyframe(0.35, 900), Keyframe(0.75, 720), Keyframe(1, 600)],
                formants: [Vowel.i.at(0), Vowel.a.at(0.3), Vowel.a.at(0.65), Vowel.u.at(1)],
                amplitude: [Keyframe(0, 0.5), Keyframe(0.3, 1), Keyframe(0.7, 0.85), Keyframe(1, 0.45)],
                vibratoRate: 5.5, vibratoDepth: 0.015, jitter: 0.006, breath: 0.05
            )
        case .demanding:
            return MeowRecipe(
                duration: 1.0,
                pitch: [Keyframe(0, 560), Keyframe(0.2, 980), Keyframe(0.65, 920), Keyframe(1, 620)],
                formants: [Vowel.i.at(0), Vowel.a.at(0.18), Vowel.a.at(0.7), Vowel.u.at(1)],
                amplitude: [Keyframe(0, 0.6), Keyframe(0.2, 1), Keyframe(0.7, 1), Keyframe(1, 0.5)],
                vibratoRate: 5, vibratoDepth: 0.02, jitter: 0.012, breath: 0.06
            )
        case .questioning:
            return MeowRecipe(
                duration: 0.6,
                pitch: [Keyframe(0, 430), Keyframe(0.4, 520), Keyframe(1, 950)],
                formants: [Vowel.m.at(0), Vowel.u.at(0.35), Vowel.a.at(0.8), Vowel.i.at(1)],
                amplitude: [Keyframe(0, 0.4), Keyframe(0.35, 0.8), Keyframe(0.8, 1), Keyframe(1, 0.6)],
                vibratoRate: 5.5, vibratoDepth: 0.01, jitter: 0.006,
                trillRate: 28, trillDepth: 0.7, trillUntil: 0.4, breath: 0.04
            )
        case .grumpy:
            return MeowRecipe(
                duration: 1.2,
                pitch: [Keyframe(0, 330), Keyframe(0.4, 560), Keyframe(0.8, 440), Keyframe(1, 360)],
                formants: [Vowel.u.at(0), Vowel.a.at(0.3), Vowel.a.at(0.7), Vowel.u.at(1)],
                amplitude: [Keyframe(0, 0.6), Keyframe(0.35, 1), Keyframe(0.8, 0.8), Keyframe(1, 0.4)],
                vibratoRate: 4.5, vibratoDepth: 0.025, jitter: 0.02,
                trillRate: 32, trillDepth: 0.35, trillUntil: 1.0, breath: 0.08
            )
        }
    }
}

// MARK: - DSP primitives

/// Deterministic pseudo-random numbers (SplitMix64), so renders are repeatable.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x123_4567
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Uniform in [-1, 1).
    mutating func bipolar() -> Double {
        unit() * 2 - 1
    }
}

/// A biquad filter (RBJ cookbook), direct form I so coefficients can glide.
struct Biquad {
    private var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    /// Band-pass with 0 dB gain at the center.
    mutating func setBandPass(frequency: Double, bandwidth: Double, sampleRate: Double) {
        let f = min(frequency, sampleRate * 0.45)
        let w0 = 2 * Double.pi * f / sampleRate
        let q = max(0.5, f / max(bandwidth, 1))
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        b0 = alpha / a0
        b1 = 0
        b2 = -alpha / a0
        a1 = -2 * cos(w0) / a0
        a2 = (1 - alpha) / a0
    }

    mutating func setLowPass(frequency: Double, q: Double, sampleRate: Double) {
        let w0 = 2 * Double.pi * min(frequency, sampleRate * 0.45) / sampleRate
        let alpha = sin(w0) / (2 * q)
        let c = cos(w0)
        let a0 = 1 + alpha
        b0 = (1 - c) / 2 / a0
        b1 = (1 - c) / a0
        b2 = (1 - c) / 2 / a0
        a1 = -2 * c / a0
        a2 = (1 - alpha) / a0
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        return y
    }
}

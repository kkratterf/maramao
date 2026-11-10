import Foundation

/// Tidies up a recorded cat before it is played: cuts the silence around it, brings it
/// to the same loudness as the others and loops it without a gap. Every function is
/// pure, like `CatVoice`: samples in, samples out, no audio APIs.
public enum CatRecording {
    /// How loud a prepared meow, mew or growl is: the level of `loudness(of:sampleRate:)`.
    public static let voiceLoudness: Float = 0.16
    /// A purr sits well under the voices.
    public static let purrLoudness: Float = 0.06
    /// No prepared recording peaks above this.
    public static let peakCeiling: Float = 0.9

    /// The recording without the silence before and after the cat. The start is cut
    /// close, so the sound answers a click at once; the end keeps its quiet tail.
    public static func trimmed(_ samples: [Float], sampleRate: Double) -> [Float] {
        let peak = peak(of: samples)
        guard peak > 0, sampleRate.isFinite, sampleRate > 0 else { return [] }
        let startLevel = peak * 0.02
        let endLevel = peak * 0.01
        guard let first = samples.firstIndex(where: { abs($0) >= startLevel }),
              let last = samples.lastIndex(where: { abs($0) >= endLevel })
        else { return [] }
        let start = max(0, first - Int(0.005 * sampleRate))
        let end = min(samples.count - 1, last + Int(0.03 * sampleRate))
        guard start <= end else { return [] }
        return Array(samples[start...end])
    }

    /// How loud the recording sounds: the RMS of its 50 ms slices, leaving out the ones
    /// more than 20 dB under the loudest, so pauses and tails do not count.
    public static func loudness(of samples: [Float], sampleRate: Double) -> Float {
        guard !samples.isEmpty, sampleRate.isFinite, sampleRate > 0 else { return 0 }
        let window = max(1, Int(0.05 * sampleRate))
        var powers: [Float] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + window)
            var sum: Float = 0
            for i in start..<end where samples[i].isFinite {
                sum += samples[i] * samples[i]
            }
            powers.append(sum / Float(end - start))
            start = end
        }
        guard let loudest = powers.max(), loudest > 0 else { return 0 }
        let gate = loudest * 0.01
        let kept = powers.filter { $0 >= gate }
        return (kept.reduce(0, +) / Float(kept.count)).squareRoot()
    }

    /// The recording at `target` loudness, quieter when that would push its peak over
    /// `peakCeiling`. Non-finite samples become silence.
    public static func leveled(_ samples: [Float], sampleRate: Double, target: Float = voiceLoudness) -> [Float] {
        let clean = samples.map { $0.isFinite ? $0 : 0 }
        let loudness = loudness(of: clean, sampleRate: sampleRate)
        let peak = peak(of: clean)
        guard loudness > 0, peak > 0 else { return clean }
        let gain = min(target / loudness, peakCeiling / peak)
        return clean.map { $0 * gain }
    }

    /// A few milliseconds of fade at both ends, so a recording never starts or stops
    /// with a click.
    public static func faded(_ samples: [Float], sampleRate: Double, seconds: Double = 0.008) -> [Float] {
        guard sampleRate.isFinite, sampleRate > 0 else { return samples }
        let fade = min(samples.count / 2, Int(seconds * sampleRate))
        guard fade > 0 else { return samples }
        var result = samples
        for i in 0..<fade {
            let level = Float(i) / Float(fade)
            result[i] *= level
            result[samples.count - 1 - i] *= level
        }
        return result
    }

    /// `count` samples of the recording played over and over. Each round blends into
    /// the next over `crossfade` samples (equal power), so a looped purr has no gap and
    /// no click where it starts again.
    public static func looped(_ samples: [Float], count: Int, crossfade: Int) -> [Float] {
        guard count > 0, !samples.isEmpty else { return [] }
        let overlap = min(max(0, crossfade), samples.count / 2)
        let period = samples.count - overlap
        var result = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let position = i % period
            if i < overlap || position >= overlap {
                result[i] = samples[position]
            } else {
                // The end of the last round fades out under the start of this one.
                let angle = Float(position) / Float(overlap) * .pi / 2
                result[i] = samples[position] * sin(angle) + samples[period + position] * cos(angle)
            }
        }
        return result
    }

    static func peak(of samples: [Float]) -> Float {
        var peak: Float = 0
        for sample in samples where sample.isFinite {
            peak = max(peak, abs(sample))
        }
        return peak
    }
}

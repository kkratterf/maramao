import XCTest
@testable import MaramaoCore

final class CatVoiceTests: XCTestCase {
    private let sampleRate = CatVoice.defaultSampleRate

    // MARK: - Shape of every sound

    func testMeowsAreAudibleBoundedAndFinite() {
        for variant in MeowVariant.allCases {
            let samples = CatVoice.renderMeow(sampleRate: sampleRate, variant: variant)
            assertPlayable(samples, name: "meow \(variant.rawValue)")
        }
    }

    func testMeowsHaveTheExpectedLength() {
        for variant in MeowVariant.allCases {
            let samples = CatVoice.renderMeow(sampleRate: sampleRate, variant: variant)
            let seconds = Double(samples.count) / sampleRate
            XCTAssertEqual(seconds, CatVoice.duration(of: variant), accuracy: 0.001, variant.rawValue)
            XCTAssertGreaterThanOrEqual(seconds, 0.5, variant.rawValue)
            XCTAssertLessThanOrEqual(seconds, 1.25, variant.rawValue)
        }
    }

    func testPurrHasTheRequestedLength() {
        for duration in [0.5, 2.0, 3.5] {
            let samples = CatVoice.renderPurr(sampleRate: sampleRate, duration: duration)
            XCTAssertEqual(Double(samples.count) / sampleRate, duration, accuracy: 0.001)
            assertPlayable(samples, name: "purr \(duration)")
        }
    }

    func testChirpAndChimeArePlayable() {
        let chirp = CatVoice.renderChirp(sampleRate: sampleRate)
        XCTAssertEqual(Double(chirp.count) / sampleRate, CatVoice.chirpDuration, accuracy: 0.001)
        assertPlayable(chirp, name: "chirp")

        let chime = CatVoice.renderChime(sampleRate: sampleRate)
        XCTAssertEqual(Double(chime.count) / sampleRate, CatVoice.chimeDuration, accuracy: 0.001)
        assertPlayable(chime, name: "chime")
    }

    func testSoundsFadeInAndOut() {
        let sounds: [(String, [Float])] = [
            ("meow", CatVoice.renderMeow(sampleRate: sampleRate, variant: .normal)),
            ("purr", CatVoice.renderPurr(sampleRate: sampleRate, duration: 2)),
            ("chirp", CatVoice.renderChirp(sampleRate: sampleRate)),
            ("chime", CatVoice.renderChime(sampleRate: sampleRate)),
        ]
        for (name, samples) in sounds {
            // No click: the first and last samples are (almost) silent.
            XCTAssertLessThan(abs(samples[0]), 0.01, name)
            XCTAssertLessThan(abs(samples[samples.count - 1]), 0.01, name)
        }
    }

    func testOtherSampleRatesWork() {
        let samples = CatVoice.renderMeow(sampleRate: 48_000, variant: .cute)
        XCTAssertEqual(Double(samples.count) / 48_000, CatVoice.duration(of: .cute), accuracy: 0.001)
        assertPlayable(samples, name: "meow at 48 kHz")
    }

    func testInvalidInputGivesSilenceNotACrash() {
        XCTAssertTrue(CatVoice.renderMeow(sampleRate: 0, variant: .normal).isEmpty)
        XCTAssertTrue(CatVoice.renderPurr(sampleRate: sampleRate, duration: 0).isEmpty)
        XCTAssertTrue(CatVoice.renderPurr(sampleRate: sampleRate, duration: -1).isEmpty)
        XCTAssertTrue(CatVoice.renderPurr(sampleRate: .nan, duration: 1).isEmpty)
        XCTAssertTrue(CatVoice.renderChime(sampleRate: -44_100).isEmpty)
    }

    func testRenderingIsDeterministic() {
        let a = CatVoice.renderMeow(sampleRate: sampleRate, variant: .demanding, seed: 7)
        let b = CatVoice.renderMeow(sampleRate: sampleRate, variant: .demanding, seed: 7)
        XCTAssertEqual(a, b)
        let c = CatVoice.renderMeow(sampleRate: sampleRate, variant: .demanding, seed: 8)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - It actually sounds like a cat

    func testNormalMeowRisesThenFalls() {
        let samples = CatVoice.renderMeow(sampleRate: sampleRate, variant: .normal)
        let start = pitch(samples, at: 0.1)
        let peak = pitch(samples, at: 0.35)
        let end = pitch(samples, at: 0.9)
        XCTAssertEqual(peak, 900, accuracy: 120)
        XCTAssertGreaterThan(peak, start + 150)
        XCTAssertGreaterThan(peak, end + 150)
    }

    func testQuestioningMeowRisesAtTheEnd() {
        let samples = CatVoice.renderMeow(sampleRate: sampleRate, variant: .questioning)
        XCTAssertGreaterThan(pitch(samples, at: 0.9), pitch(samples, at: 0.1) * 1.6)
    }

    func testKittenIsHigherAndGrumpyIsLower() {
        let normal = pitch(CatVoice.renderMeow(sampleRate: sampleRate, variant: .normal), at: 0.35)
        let cute = pitch(CatVoice.renderMeow(sampleRate: sampleRate, variant: .cute), at: 0.35)
        let grumpy = pitch(CatVoice.renderMeow(sampleRate: sampleRate, variant: .grumpy), at: 0.35)
        XCTAssertGreaterThan(cute, normal + 100)
        XCTAssertLessThan(grumpy, normal - 100)
        XCTAssertGreaterThan(CatVoice.duration(of: .grumpy), CatVoice.duration(of: .normal))
    }

    func testPurrIsLowPitched() {
        let samples = CatVoice.renderPurr(sampleRate: sampleRate, duration: 2)
        // Crossings of zero per second: a low-passed rumble stays far below a meow.
        var crossings = 0
        for i in 1..<samples.count where (samples[i - 1] < 0) != (samples[i] < 0) {
            crossings += 1
        }
        let perSecond = Double(crossings) / 2
        XCTAssertLessThan(perSecond, 900)
        XCTAssertGreaterThan(perSecond, 40)
    }

    // MARK: - Helpers

    private func assertPlayable(_ samples: [Float], name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(samples.isEmpty, name, file: file, line: line)
        var peak: Float = 0
        var energy: Double = 0
        for x in samples {
            XCTAssertTrue(x.isFinite, "\(name) has a non-finite sample", file: file, line: line)
            if !x.isFinite { return }
            peak = max(peak, abs(x))
            energy += Double(x) * Double(x)
        }
        XCTAssertLessThanOrEqual(peak, 1, "\(name) clips", file: file, line: line)
        XCTAssertGreaterThan(peak, 0.3, "\(name) is too quiet", file: file, line: line)
        let rms = (energy / Double(samples.count)).squareRoot()
        XCTAssertGreaterThan(rms, 0.02, "\(name) is nearly silent", file: file, line: line)
    }

    /// Fundamental frequency around a point (0...1) of the sound, by autocorrelation.
    private func pitch(_ samples: [Float], at position: Double) -> Double {
        let frame = 2048
        let center = Int(position * Double(samples.count))
        let start = max(0, min(samples.count - frame, center - frame / 2))
        let shortestLag = Int(sampleRate / 1500)
        let longestLag = Int(sampleRate / 250)
        var bestLag = shortestLag
        var best = -Double.greatestFiniteMagnitude
        for lag in shortestLag...longestLag {
            var sum = 0.0
            for i in start..<(start + frame - lag) {
                sum += Double(samples[i]) * Double(samples[i + lag])
            }
            if sum > best {
                best = sum
                bestLag = lag
            }
        }
        return sampleRate / Double(bestLag)
    }
}

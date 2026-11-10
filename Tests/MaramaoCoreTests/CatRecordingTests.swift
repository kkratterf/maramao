import XCTest
@testable import MaramaoCore

final class CatRecordingTests: XCTestCase {
    private let sampleRate: Double = 44_100

    /// A 440 Hz tone of the given length and amplitude.
    private func tone(seconds: Double, amplitude: Float) -> [Float] {
        let count = Int(seconds * sampleRate)
        return (0..<count).map { amplitude * Float(sin(2 * Double.pi * 440 * Double($0) / sampleRate)) }
    }

    private func silence(seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * sampleRate))
    }

    // MARK: - Trimming

    func testTrimmingCutsTheSilenceAroundTheCat() {
        let recording = silence(seconds: 0.2) + tone(seconds: 0.5, amplitude: 0.8) + silence(seconds: 0.4)
        let trimmed = CatRecording.trimmed(recording, sampleRate: sampleRate)
        let seconds = Double(trimmed.count) / sampleRate
        XCTAssertGreaterThanOrEqual(seconds, 0.5)
        XCTAssertLessThan(seconds, 0.56)
        // The cat starts within a few milliseconds.
        let start = trimmed.firstIndex { abs($0) > 0.1 } ?? .max
        XCTAssertLessThan(Double(start) / sampleRate, 0.01)
    }

    func testTrimmingKeepsAQuietTail() {
        let recording = tone(seconds: 0.3, amplitude: 0.8) + tone(seconds: 0.3, amplitude: 0.012)
        let trimmed = CatRecording.trimmed(recording, sampleRate: sampleRate)
        XCTAssertGreaterThan(Double(trimmed.count) / sampleRate, 0.59)
    }

    func testTrimmingARecordingWithoutSilenceChangesNothing() {
        let recording = tone(seconds: 0.4, amplitude: 0.5)
        let trimmed = CatRecording.trimmed(recording, sampleRate: sampleRate)
        XCTAssertLessThanOrEqual(recording.count - trimmed.count, 4)
    }

    func testTrimmingSilenceOrNothingGivesNothing() {
        XCTAssertTrue(CatRecording.trimmed([], sampleRate: sampleRate).isEmpty)
        XCTAssertTrue(CatRecording.trimmed(silence(seconds: 0.3), sampleRate: sampleRate).isEmpty)
        XCTAssertTrue(CatRecording.trimmed(tone(seconds: 0.3, amplitude: 0.5), sampleRate: 0).isEmpty)
    }

    // MARK: - Loudness

    func testLoudnessOfATone() {
        // The RMS of a sine is its amplitude over the square root of two.
        let loudness = CatRecording.loudness(of: tone(seconds: 0.5, amplitude: 0.5), sampleRate: sampleRate)
        XCTAssertEqual(loudness, 0.5 / Float(2).squareRoot(), accuracy: 0.005)
    }

    func testLoudnessIgnoresPauses() {
        let meow = tone(seconds: 0.4, amplitude: 0.5)
        let withPauses = silence(seconds: 0.3) + meow + silence(seconds: 0.6)
        XCTAssertEqual(
            CatRecording.loudness(of: withPauses, sampleRate: sampleRate),
            CatRecording.loudness(of: meow, sampleRate: sampleRate),
            accuracy: 0.01
        )
    }

    func testLoudnessOfSilenceIsZero() {
        XCTAssertEqual(CatRecording.loudness(of: [], sampleRate: sampleRate), 0)
        XCTAssertEqual(CatRecording.loudness(of: silence(seconds: 0.2), sampleRate: sampleRate), 0)
    }

    func testLevelingBringsQuietAndLoudCatsTogether() {
        let quiet = CatRecording.leveled(tone(seconds: 0.5, amplitude: 0.05), sampleRate: sampleRate)
        let loud = CatRecording.leveled(tone(seconds: 0.5, amplitude: 0.95), sampleRate: sampleRate)
        for samples in [quiet, loud] {
            XCTAssertEqual(
                CatRecording.loudness(of: samples, sampleRate: sampleRate),
                CatRecording.voiceLoudness,
                accuracy: 0.002
            )
        }
    }

    func testLevelingNeverPushesThePeakOverTheCeiling() {
        // One loud click in a quiet recording: the peak, not the loudness, sets the gain.
        var recording = tone(seconds: 0.5, amplitude: 0.01)
        recording[1000] = 0.5
        let leveled = CatRecording.leveled(recording, sampleRate: sampleRate)
        XCTAssertEqual(CatRecording.peak(of: leveled), CatRecording.peakCeiling, accuracy: 0.001)
    }

    func testLevelingDropsNonFiniteSamples() {
        var recording = tone(seconds: 0.2, amplitude: 0.4)
        recording[10] = .nan
        recording[20] = .infinity
        let leveled = CatRecording.leveled(recording, sampleRate: sampleRate)
        XCTAssertTrue(leveled.allSatisfy { $0.isFinite })
        XCTAssertEqual(leveled.count, recording.count)
    }

    // MARK: - Fades

    func testFadeSilencesBothEnds() {
        let faded = CatRecording.faded([Float](repeating: 1, count: 4410), sampleRate: sampleRate)
        XCTAssertEqual(faded.first, 0)
        XCTAssertEqual(faded.last, 0)
        XCTAssertEqual(faded[2205], 1)
        XCTAssertEqual(faded.count, 4410)
    }

    func testFadeOfAVeryShortRecordingDoesNotCrash() {
        XCTAssertEqual(CatRecording.faded([], sampleRate: sampleRate), [])
        XCTAssertEqual(CatRecording.faded([1], sampleRate: sampleRate), [1])
        XCTAssertEqual(CatRecording.faded([1, 1, 1], sampleRate: sampleRate).count, 3)
    }

    // MARK: - Looping

    func testLoopHasTheRequestedLength() {
        let purr = tone(seconds: 0.5, amplitude: 0.3)
        for count in [1, 100, purr.count, purr.count * 3 + 17] {
            XCTAssertEqual(CatRecording.looped(purr, count: count, crossfade: 2000).count, count)
        }
        XCTAssertTrue(CatRecording.looped(purr, count: 0, crossfade: 2000).isEmpty)
        XCTAssertTrue(CatRecording.looped([], count: 100, crossfade: 2000).isEmpty)
    }

    func testLoopShorterThanTheRecordingIsTheRecording() {
        let purr = tone(seconds: 0.5, amplitude: 0.3)
        let cut = CatRecording.looped(purr, count: 5000, crossfade: 2000)
        XCTAssertEqual(cut, Array(purr[0..<5000]))
    }

    func testLoopNeverGoesSilentWhereItStartsAgain() {
        // A recording that fades in and out, like the purr after `faded`.
        let purr = CatRecording.faded(tone(seconds: 0.5, amplitude: 0.3), sampleRate: sampleRate, seconds: 0.05)
        let looped = CatRecording.looped(purr, count: purr.count * 4, crossfade: Int(0.1 * sampleRate))
        // Skip the fade-in of the very first round, then every 20 ms slice must be heard.
        let window = Int(0.02 * sampleRate)
        var start = Int(0.06 * sampleRate)
        while start + window <= looped.count - Int(0.06 * sampleRate) {
            let slice = Array(looped[start..<start + window])
            XCTAssertGreaterThan(CatRecording.peak(of: slice), 0.1, "silent around sample \(start)")
            start += window
        }
    }

    func testLoopHasNoJumpWhereItStartsAgain() {
        // A ramp jumps from 1 back to 0 when looped naively.
        let ramp = (0..<10_000).map { Float($0) / 10_000 }
        let looped = CatRecording.looped(ramp, count: 40_000, crossfade: 2000)
        var largestStep: Float = 0
        for i in 1..<looped.count {
            largestStep = max(largestStep, abs(looped[i] - looped[i - 1]))
        }
        XCTAssertLessThan(largestStep, 0.01)
    }

    func testLoopWithAnOversizedCrossfadeStillWorks() {
        let purr = tone(seconds: 0.1, amplitude: 0.3)
        let looped = CatRecording.looped(purr, count: 20_000, crossfade: 1_000_000)
        XCTAssertEqual(looped.count, 20_000)
        XCTAssertTrue(looped.allSatisfy { $0.isFinite && abs($0) <= 0.5 })
    }
}

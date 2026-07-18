import Testing
@testable import Weeklight

struct DurationTextTests {
    @Test("Compact durations omit empty units", arguments: [
        (0.0, "0m"),
        (45.0 * 60, "45m"),
        (2.0 * 60 * 60, "2h"),
        (2.0 * 60 * 60 + 5 * 60, "2h 5m")
    ])
    func compact(duration: Double, expected: String) {
        #expect(DurationText.compact(duration) == expected)
    }

    @Test("Clock durations use a stable monospaced representation")
    func clock() {
        #expect(DurationText.clock(3_661) == "01:01:01")
    }

    @Test("Countdown clocks round up partial seconds")
    func countdownClock() {
        #expect(DurationText.countdownClock(59.1) == "00:01:00")
    }
}

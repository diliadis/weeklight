import Testing
@testable import Weeklight

struct DurationTextTests {
    @Test("Compact durations omit empty units")
    func compact() {
        #expect(DurationText.compact(0) == "0m")
        #expect(DurationText.compact(45 * 60) == "45m")
        #expect(DurationText.compact(2 * 60 * 60) == "2h")
        #expect(DurationText.compact(2 * 60 * 60 + 5 * 60) == "2h 5m")
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

import Foundation
import Testing
@testable import Weeklight

struct TrackingMathTests {
    @Test("Only the portion inside the selected week is counted")
    func clipsEntryToWeek() {
        let weekStart = Date(timeIntervalSince1970: 1_000_000)
        let interval = DateInterval(
            start: weekStart,
            end: weekStart.addingTimeInterval(7 * 24 * 60 * 60)
        )
        let entryStart = weekStart.addingTimeInterval(-30 * 60)
        let entryEnd = weekStart.addingTimeInterval(90 * 60)

        let result = TrackingMath.overlapDuration(
            startedAt: entryStart,
            endedAt: entryEnd,
            interval: interval
        )

        #expect(result == 90 * 60)
    }

    @Test("Non-overlapping intervals return zero")
    func noOverlap() {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 1_000),
            duration: 500
        )

        #expect(
            TrackingMath.overlapDuration(
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 900),
                interval: interval
            ) == 0
        )
    }

    @Test("Touching intervals do not overlap")
    func touchingIntervals() {
        let boundary = Date(timeIntervalSince1970: 500)

        #expect(
            !TrackingMath.intervalsOverlap(
                start: Date(timeIntervalSince1970: 100),
                end: boundary,
                otherStart: boundary,
                otherEnd: Date(timeIntervalSince1970: 900)
            )
        )
    }

    @Test("Project progress exposes remaining time and overrun")
    func projectProgress() {
        let progress = ProjectProgress(
            plannedMinutes: 60,
            trackedSeconds: 75 * 60
        )

        #expect(progress.remainingSeconds == 0)
        #expect(progress.fractionCompleted == 1.25)
    }

    @Test("Countdown finishing state uses a bounded relative threshold")
    func countdownFinishingSoon() {
        #expect(
            TrackingMath.isCountdownFinishingSoon(
                totalDuration: 30 * 60,
                remainingDuration: 3 * 60
            )
        )
        #expect(
            !TrackingMath.isCountdownFinishingSoon(
                totalDuration: 30 * 60,
                remainingDuration: 4 * 60
            )
        )
        #expect(
            TrackingMath.isCountdownFinishingSoon(
                totalDuration: 2 * 60 * 60,
                remainingDuration: 5 * 60
            )
        )
    }
}

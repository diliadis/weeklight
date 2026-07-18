import Foundation
import Testing
@testable import Weeklight

@Suite("Timer notification policy")
struct TimerNotificationPolicyTests {
    private let enabled = TimerNotificationPreferences(
        isEnabled: true,
        finishingSoonEnabled: true,
        completionEnabled: true,
        allocationExceededEnabled: true
    )

    @Test("A countdown schedules finishing and completion alerts")
    func countdownSchedule() throws {
        let schedule = TimerNotificationPolicy.schedule(
            countdownDuration: 30 * 60,
            elapsedDuration: 10 * 60,
            allocationRemaining: 8 * 60 * 60,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: enabled
        )

        let finishingSoonDelay = try #require(schedule.finishingSoonDelay)
        let completionDelay = try #require(schedule.completionDelay)
        #expect(finishingSoonDelay == 17 * 60)
        #expect(completionDelay == 20 * 60)
        #expect(schedule.allocationExceededDelay == nil)
    }

    @Test("Resuming inside the warning window schedules an immediate warning")
    func resumedCountdownSchedule() throws {
        let schedule = TimerNotificationPolicy.schedule(
            countdownDuration: 30 * 60,
            elapsedDuration: 28 * 60,
            allocationRemaining: nil,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: enabled
        )

        let finishingSoonDelay = try #require(schedule.finishingSoonDelay)
        let completionDelay = try #require(schedule.completionDelay)
        #expect(finishingSoonDelay == 1)
        #expect(completionDelay == 2 * 60)
    }

    @Test("A stopwatch schedules the future allocation crossing")
    func allocationSchedule() throws {
        let schedule = TimerNotificationPolicy.schedule(
            countdownDuration: nil,
            elapsedDuration: 15 * 60,
            allocationRemaining: 45 * 60,
            secondsUntilWeekEnds: 2 * 24 * 60 * 60,
            preferences: enabled
        )

        #expect(schedule.finishingSoonDelay == nil)
        #expect(schedule.completionDelay == nil)
        let allocationExceededDelay = try #require(
            schedule.allocationExceededDelay
        )
        #expect(allocationExceededDelay == 45 * 60)
    }

    @Test("A timer at its allocation boundary warns on the next second")
    func exactAllocationBoundary() throws {
        let schedule = TimerNotificationPolicy.schedule(
            countdownDuration: nil,
            elapsedDuration: 0,
            allocationRemaining: 0,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: enabled
        )

        let allocationExceededDelay = try #require(
            schedule.allocationExceededDelay
        )
        #expect(allocationExceededDelay == 1)
    }

    @Test("Allocation alerts do not escape the current week or outlive a countdown")
    func allocationBoundaries() {
        let weekEndsFirst = TimerNotificationPolicy.schedule(
            countdownDuration: nil,
            elapsedDuration: 0,
            allocationRemaining: 2 * 60 * 60,
            secondsUntilWeekEnds: 60 * 60,
            preferences: enabled
        )
        let countdownEndsFirst = TimerNotificationPolicy.schedule(
            countdownDuration: 30 * 60,
            elapsedDuration: 0,
            allocationRemaining: 45 * 60,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: enabled
        )

        #expect(weekEndsFirst.allocationExceededDelay == nil)
        #expect(countdownEndsFirst.allocationExceededDelay == nil)
    }

    @Test("Disabling notifications produces no pending work")
    func disabledSchedule() {
        let schedule = TimerNotificationPolicy.schedule(
            countdownDuration: 30 * 60,
            elapsedDuration: 0,
            allocationRemaining: 15 * 60,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: TimerNotificationPreferences(
                isEnabled: false,
                finishingSoonEnabled: true,
                completionEnabled: true,
                allocationExceededEnabled: true
            )
        )

        #expect(schedule == .empty)
    }
}

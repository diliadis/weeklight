import Foundation

struct TimerNotificationPreferences: Equatable, Sendable {
    var isEnabled: Bool
    var finishingSoonEnabled: Bool
    var completionEnabled: Bool
    var allocationExceededEnabled: Bool
}

struct TimerNotificationSchedule: Equatable, Sendable {
    var finishingSoonDelay: TimeInterval?
    var completionDelay: TimeInterval?
    var allocationExceededDelay: TimeInterval?

    static let empty = TimerNotificationSchedule(
        finishingSoonDelay: nil,
        completionDelay: nil,
        allocationExceededDelay: nil
    )
}

enum TimerNotificationPolicy {
    static func schedule(
        countdownDuration: TimeInterval?,
        elapsedDuration: TimeInterval,
        allocationRemaining: TimeInterval?,
        secondsUntilWeekEnds: TimeInterval,
        preferences: TimerNotificationPreferences
    ) -> TimerNotificationSchedule {
        guard preferences.isEnabled else { return .empty }

        let countdownRemaining = countdownDuration.map {
            max(0, $0 - max(0, elapsedDuration))
        }
        var schedule = TimerNotificationSchedule.empty

        if let countdownDuration,
           let countdownRemaining,
           countdownRemaining > 0 {
            if preferences.finishingSoonEnabled {
                let threshold = TrackingMath.countdownFinishingThreshold(
                    totalDuration: countdownDuration
                )
                schedule.finishingSoonDelay = max(
                    1,
                    countdownRemaining - threshold
                )
            }
            if preferences.completionEnabled {
                schedule.completionDelay = max(1, countdownRemaining)
            }
        }

        if preferences.allocationExceededEnabled,
           let allocationRemaining,
           allocationRemaining >= 0,
           allocationRemaining < secondsUntilWeekEnds,
           countdownRemaining.map({ allocationRemaining < $0 }) ?? true {
            schedule.allocationExceededDelay = max(1, allocationRemaining)
        }

        return schedule
    }
}

import Foundation

struct ProjectProgress: Equatable, Sendable {
    let plannedMinutes: Int
    let trackedSeconds: TimeInterval

    var trackedMinutes: Int {
        Int(trackedSeconds / 60)
    }

    var remainingSeconds: TimeInterval {
        max(0, TimeInterval(plannedMinutes * 60) - trackedSeconds)
    }

    var fractionCompleted: Double {
        guard plannedMinutes > 0 else {
            return trackedSeconds > 0 ? 1 : 0
        }
        return trackedSeconds / TimeInterval(plannedMinutes * 60)
    }
}

enum TrackingMath {
    static func overlapDuration(
        startedAt: Date,
        endedAt: Date,
        interval: DateInterval
    ) -> TimeInterval {
        let overlapStart = max(startedAt, interval.start)
        let overlapEnd = min(endedAt, interval.end)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }

    static func trackedDuration(
        for projectID: UUID? = nil,
        entries: [TimeEntry],
        interval: DateInterval,
        now: Date
    ) -> TimeInterval {
        entries.reduce(0) { total, entry in
            guard projectID == nil || entry.project?.id == projectID else {
                return total
            }
            return total + overlapDuration(
                startedAt: entry.startedAt,
                endedAt: entry.endedAt ?? now,
                interval: interval
            )
        }
    }

    static func intervalsOverlap(
        start: Date,
        end: Date,
        otherStart: Date,
        otherEnd: Date
    ) -> Bool {
        start < otherEnd && otherStart < end
    }

    static func isCountdownFinishingSoon(
        totalDuration: TimeInterval,
        remainingDuration: TimeInterval
    ) -> Bool {
        guard totalDuration > 0, remainingDuration > 0 else { return false }
        let threshold = countdownFinishingThreshold(totalDuration: totalDuration)
        return remainingDuration <= threshold
    }

    static func countdownFinishingThreshold(
        totalDuration: TimeInterval
    ) -> TimeInterval {
        min(5 * 60, max(30, totalDuration * 0.1))
    }
}

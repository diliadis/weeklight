import Foundation

enum DurationText {
    static func compact(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    static func clock(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func countdownClock(_ duration: TimeInterval) -> String {
        clock(ceil(max(0, duration)))
    }

    static func hours(_ minutes: Int) -> String {
        let value = Double(minutes) / 60
        if value.rounded() == value {
            return "\(Int(value))h"
        }
        return value.formatted(.number.precision(.fractionLength(1))) + "h"
    }
}

import Foundation

enum WeeklightFormatters {
    static let weekRange: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static func weekTitle(_ weekStart: Date) -> String {
        let interval = WeekMath.interval(containing: weekStart)
        return weekRange.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
    }
}

import Foundation

enum WeekMath {
    static func mondayFirstCalendar(
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func startOfWeek(
        containing date: Date,
        calendar: Calendar = mondayFirstCalendar()
    ) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart)
        let daysSinceFirstWeekday = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(
            byAdding: .day,
            value: -daysSinceFirstWeekday,
            to: dayStart
        ) ?? dayStart
    }

    static func interval(
        containing date: Date,
        calendar: Calendar = mondayFirstCalendar()
    ) -> DateInterval {
        let start = startOfWeek(containing: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start)
            ?? start.addingTimeInterval(7 * 24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    static func offset(
        _ weekStart: Date,
        by weeks: Int,
        calendar: Calendar = mondayFirstCalendar()
    ) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart)
            ?? weekStart.addingTimeInterval(TimeInterval(weeks * 7 * 24 * 60 * 60))
    }
}

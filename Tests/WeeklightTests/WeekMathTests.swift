import Foundation
import Testing
@testable import Weeklight

struct WeekMathTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test("A Wednesday resolves to the preceding Monday")
    func mondayWeekStart() throws {
        let calendar = WeekMath.mondayFirstCalendar(timeZone: utc)
        let wednesday = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 13))
        )
        let expectedMonday = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))
        )

        #expect(WeekMath.startOfWeek(containing: wednesday, calendar: calendar) == expectedMonday)
    }

    @Test("Week offsets use calendar weeks")
    func weekOffset() throws {
        let calendar = WeekMath.mondayFirstCalendar(timeZone: utc)
        let monday = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))
        )
        let expected = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 27))
        )

        #expect(WeekMath.offset(monday, by: 2, calendar: calendar) == expected)
    }

    @Test("A week interval spans seven local calendar days across DST")
    func intervalAcrossDaylightSaving() throws {
        let brussels = try #require(TimeZone(identifier: "Europe/Brussels"))
        let calendar = WeekMath.mondayFirstCalendar(timeZone: brussels)
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 25, hour: 12))
        )
        let interval = WeekMath.interval(containing: date, calendar: calendar)
        let dayDifference = calendar.dateComponents(
            [.day],
            from: interval.start,
            to: interval.end
        ).day

        #expect(dayDifference == 7)
    }
}

//
//  CalendarGridTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("CalendarGrid")
struct CalendarGridTests {

    /// A calendar built from a locale carries that region's conventions —
    /// notably `firstWeekday` — which is exactly what the component relies on.
    private static func calendar(_ localeID: String, timeZone: String = "Europe/Paris") -> Calendar {
        var calendar = Locale(identifier: localeID).calendar
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    @Test("Weeks start on the day the phone's region says they do", arguments: [
        ("fr_FR", 2), ("en_US", 1), ("en_GB", 2),
    ])
    func firstWeekday(localeID: String, expected: Int) {
        #expect(Self.calendar(localeID).firstWeekday == expected)
    }

    @Test("Weekday initials are rotated to match the first column")
    func weekdaySymbolsAreRotated() {
        let french = CalendarGrid(calendar: Self.calendar("fr_FR")).weekdaySymbols
        #expect(french.first == "L")
        #expect(french.last == "D")
        #expect(french.count == 7)

        // The same symbols unrotated would label Monday's column "S".
        let american = CalendarGrid(calendar: Self.calendar("en_US")).weekdaySymbols
        #expect(american.first == "S")
        #expect(american.count == 7)
    }

    @Test("The week containing a day starts on the region's first weekday")
    func startOfWeek() throws {
        // 7 September 2026 is a Monday.
        let french = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: french)
        let monday = try Self.date(2026, 9, 7, in: french)
        let wednesday = try Self.date(2026, 9, 9, in: french)

        #expect(grid.startOfWeek(containing: monday) == monday)
        #expect(grid.startOfWeek(containing: wednesday) == monday)

        // The same Wednesday, on a phone whose weeks start on Sunday.
        let american = Self.calendar("en_US")
        let sunday = try Self.date(2026, 9, 6, in: american)
        #expect(CalendarGrid(calendar: american).startOfWeek(containing: wednesday) == sunday)
    }

    @Test("A month page is always six whole weeks, whatever the month")
    func monthPageIsSixWeeks() throws {
        let calendar = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: calendar)

        // February 2027 fits in four weeks and a day; September 2026 needs five.
        for (year, month) in [(2027, 2), (2026, 9), (2026, 3)] {
            let page = grid.monthPage(containing: try Self.date(year, month, 1, in: calendar))
            #expect(page.count == 42)
            #expect(calendar.component(.weekday, from: try #require(page.first)) == calendar.firstWeekday)
        }
    }

    @Test("A month page starts on the week holding the 1st")
    func monthPageLeadingDays() throws {
        let calendar = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: calendar)
        // 1 September 2026 is a Tuesday, so the page opens on Monday 31 August.
        let page = grid.monthPage(containing: try Self.date(2026, 9, 15, in: calendar))

        #expect(try #require(page.first) == (try Self.date(2026, 8, 31, in: calendar)))
        #expect(page.contains(try Self.date(2026, 9, 1, in: calendar)))
        #expect(page.contains(try Self.date(2026, 9, 30, in: calendar)))
    }

    @Test("A day's row is where the collapsed card lands")
    func rowIndex() throws {
        let calendar = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: calendar)
        let page = grid.monthPage(containing: try Self.date(2026, 9, 7, in: calendar))

        // Row 0 is 31 Aug–6 Sep, so Monday the 7th opens row 1.
        #expect(grid.rowIndex(of: try Self.date(2026, 8, 31, in: calendar), in: page) == 0)
        #expect(grid.rowIndex(of: try Self.date(2026, 9, 7, in: calendar), in: page) == 1)
        #expect(grid.rowIndex(of: try Self.date(2026, 9, 30, in: calendar), in: page) == 4)
        #expect(grid.rowIndex(of: try Self.date(2026, 12, 25, in: calendar), in: page) == nil)
    }

    @Test("Every day of a page sits at midnight, including across a DST change")
    func daylightSavingKeepsDaysAtMidnight() throws {
        let calendar = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: calendar)
        // Clocks go forward on Sunday 29 March 2026 in Paris.
        let page = grid.monthPage(containing: try Self.date(2026, 3, 15, in: calendar))

        #expect(page.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        #expect(page.contains(try Self.date(2026, 3, 29, in: calendar)))
    }

    @Test("Paging months from the 1st cannot drift onto a shorter month")
    func monthPagingDoesNotDrift() throws {
        let calendar = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: calendar)
        var cursor = grid.startOfMonth(containing: try Self.date(2026, 1, 31, in: calendar))

        for _ in 0 ..< 3 { cursor = grid.date(byAddingMonths: 1, to: cursor) }

        #expect(cursor == (try Self.date(2026, 4, 1, in: calendar)))
    }

    @Test("Paging weeks crosses month and year boundaries")
    func weekPaging() throws {
        let calendar = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: calendar)
        let lastMondayOf2026 = try Self.date(2026, 12, 28, in: calendar)

        #expect(grid.date(byAddingWeeks: 1, to: lastMondayOf2026) == (try Self.date(2027, 1, 4, in: calendar)))
        #expect(grid.date(byAddingWeeks: -1, to: lastMondayOf2026) == (try Self.date(2026, 12, 21, in: calendar)))
    }

    @Test("Borrowed days are flagged as belonging to another month")
    func daysOutsideTheDisplayedMonth() throws {
        let calendar = Self.calendar("fr_FR")
        let grid = CalendarGrid(calendar: calendar)
        let september = try Self.date(2026, 9, 15, in: calendar)

        #expect(grid.isDate(try Self.date(2026, 9, 1, in: calendar), inSameMonthAs: september))
        #expect(!grid.isDate(try Self.date(2026, 8, 31, in: calendar), inSameMonthAs: september))
        #expect(!grid.isDate(try Self.date(2025, 9, 15, in: calendar), inSameMonthAs: september))
    }

    @Test("The title is localised and reads as a heading")
    func monthTitle() throws {
        let french = Self.calendar("fr_FR")
        let title = CalendarGrid(calendar: french).monthTitle(for: try Self.date(2026, 9, 7, in: french))
        #expect(title == "Septembre 2026")

        let american = Self.calendar("en_US", timeZone: "America/New_York")
        let englishTitle = CalendarGrid(calendar: american).monthTitle(for: try Self.date(2026, 9, 7, in: american))
        #expect(englishTitle == "September 2026")
    }
}

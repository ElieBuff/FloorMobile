//
//  CalendarGrid.swift
//  FloorMobile
//

import Foundation

/// The date arithmetic behind `CollapsibleCalendar`, kept out of the view so it
/// can be tested without one.
///
/// Everything here is expressed in *the phone's* calendar: which day a week
/// starts on, what the weekday initials read, and how a month falls on a grid
/// all come from `Calendar.current` and its locale, never from constants. The
/// same code gives a French phone weeks starting on Monday labelled
/// "L M M J V S D", and an American one weeks starting on Sunday labelled
/// "S M T W T F S".
nonisolated struct CalendarGrid: Equatable, Sendable {
    /// Rows in a month page. Fixed rather than fitted to each month: a page that
    /// changed height between a 5-week month and a 6-week one would make
    /// everything below the calendar jump as you page through the year.
    static let rowCount = 6
    static let daysPerWeek = 7

    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Weekday initials in display order, rotated so the first column is the
    /// calendar's own first weekday.
    ///
    /// `veryShortWeekdaySymbols` is always Sunday-first whatever the locale, so
    /// showing it unrotated would label the right columns with the wrong days on
    /// any phone that doesn't start its week on Sunday.
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        guard symbols.count == Self.daysPerWeek, symbols.indices.contains(first) else { return symbols }
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Midnight on the first day of the week containing `date`.
    func startOfWeek(containing date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + Self.daysPerWeek) % Self.daysPerWeek
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    /// Midnight on the first day of the month containing `date`.
    func startOfMonth(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }

    /// The six-week page showing `date`'s month: the month's own days, plus the
    /// leading and trailing days needed to fill whole weeks.
    func monthPage(containing date: Date) -> [Date] {
        days(fromWeekStart: startOfWeek(containing: startOfMonth(containing: date)), rows: Self.rowCount)
    }

    /// The seven days of the week containing `date`.
    func week(containing date: Date) -> [Date] {
        days(fromWeekStart: startOfWeek(containing: date), rows: 1)
    }

    /// Which row of `page` holds `date`.
    func rowIndex(of date: Date, in page: [Date]) -> Int? {
        guard let index = page.firstIndex(where: { isSameDay($0, date) }) else { return nil }
        return index / Self.daysPerWeek
    }

    func date(byAddingWeeks weeks: Int, to date: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
    }

    func date(byAddingMonths months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    func isSameDay(_ date: Date, _ other: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: other)
    }

    func isDate(_ date: Date, inSameMonthAs other: Date) -> Bool {
        calendar.isDate(date, equalTo: other, toGranularity: .month)
    }

    func dayNumber(of date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    /// "Septembre 2026" — localised, and capitalised the way a title is. French
    /// writes months in lower case in a sentence, but this one is a heading.
    func monthTitle(for date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(calendar.locale ?? .current)
                .month(.wide)
                .year()
        ).localizedCapitalized
    }

    /// Adding days one at a time rather than multiplying seconds: only the
    /// calendar knows that a day is 23 or 25 hours long across a DST change.
    private func days(fromWeekStart start: Date, rows: Int) -> [Date] {
        (0 ..< (rows * Self.daysPerWeek)).map {
            calendar.date(byAdding: .day, value: $0, to: start) ?? start
        }
    }
}

//
//  Date+Calendar.swift
//  FloorMobile
//

import Foundation

nonisolated extension Date {
    /// Midnight at the start of this date's day, in the current calendar.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Midnight at the start of the day after this date's day.
    var startOfNextDay: Date {
        let start = startOfDay
        return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
    }
}

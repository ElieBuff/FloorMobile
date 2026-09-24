//
//  Date+NextHour.swift
//  FloorMobile
//

import Foundation

nonisolated extension Date {
    /// The next whole hour, strictly after this instant: 11:50 becomes 12:00,
    /// and so does 11:00 — an instant already on the hour moves on rather than
    /// standing still.
    ///
    /// Floor to the hour, then add one. One rule for both cases, so there is no
    /// boundary to get wrong, and the minutes and seconds go on the way.
    /// `byAdding` rather than 3600 seconds, so the hour a daylight-saving
    /// change shortens or lengthens still lands on the clock face.
    func nextHour(_ calendar: Calendar = .current) -> Date {
        let startOfHour = calendar.dateInterval(of: .hour, for: self)?.start ?? self
        return calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? self
    }
}

//
//  ReminderOffset.swift
//  FloorMobile
//

import Foundation

/// How long before an appointment its reminder fires — in minutes, which is how
/// an advisor thinks about it, and `nil` for no reminder at all.
///
/// The API stores an instant (`reminderDate`); nobody picks an instant. The
/// whole concept lives here so the three things that make it up stay together:
/// what a form may offer, how the instant turns back into an offset, and how
/// the offset reads. A composer edits it, a detail screen shows it, and neither
/// owns it.
nonisolated enum ReminderOffset {

    /// What a form offers, "none" first.
    ///
    /// Nothing beyond the hour: a reminder that fires the day before belongs to
    /// planning, not to the shop floor, and an advisor setting one here is
    /// almost always aiming at "just before".
    static let selectable: [Int?] = [nil, 5, 15, 30, 60]

    /// The offset recovered from the instant the API stores.
    ///
    /// Rounded to the minute: both instants carry seconds of their own, and
    /// "29 min before" for a half-hour reminder would be a rounding artefact on
    /// screen. A reminder at or after the start is no offset anyone chose,
    /// hence `nil`.
    static func minutes(from reminderDate: Date?, before startDate: Date) -> Int? {
        guard let reminderDate else { return nil }
        let minutes = Int((startDate.timeIntervalSince(reminderDate) / 60).rounded())
        return minutes > 0 ? minutes : nil
    }

    /// "30 min before", or "None" when there is no reminder.
    static func label(_ offset: Int?) -> String {
        guard let offset else { return String(localized: "None") }
        return String(localized: "\(Duration.minutes(offset).hoursAndMinutes) before")
    }
}

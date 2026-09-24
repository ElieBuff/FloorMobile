//
//  EventStatus.swift
//  FloorMobile
//

import Foundation

/// What the server says about an event's booking — the API's `status` (open
/// set). Typed the same way as `Reason`: the model keeps the raw string so an
/// unknown value can never break decoding, and this enum is the view of it.
///
/// Note what is *not* here: no "in progress", no "past". The server never moves
/// a booking on its own as the day goes by — `PLANNED` stays `PLANNED` long
/// after the slot has elapsed. Whether an event has run its course is a
/// question for the clock, answered in `DayTimeline`.
nonisolated enum EventStatus: String, CaseIterable, Sendable {
    case planned = "PLANNED"
    case confirmed = "CONFIRMED"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case other = "OTHER"

    /// Maps a raw server value, defaulting to `.other` for anything unknown.
    init(raw: String) {
        self = EventStatus(rawValue: raw) ?? .other
    }
}

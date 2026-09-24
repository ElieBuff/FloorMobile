//
//  FieldOptionKey+Agenda.swift
//  FloorMobile
//

import Foundation

/// The vocabulary keys the agenda reads. One line per (entity, field) an
/// agenda screen offers as a choice — the store holds whatever else the
/// server sends, named or not.
nonisolated extension FieldOption.Key {
    static let taskReason = Self(entityName: "task", field: "reason")
    static let eventReason = Self(entityName: "event", field: "reason")
    /// `TaskStatus` and `EventStatus`. Two lists, not one: a task is never
    /// planned or confirmed, and the two spell cancellation differently.
    static let taskStatus = Self(entityName: "task", field: "status")
    static let eventStatus = Self(entityName: "event", field: "status")
    /// `MeetingType`. Published as `event.meetingType`, which is also the name
    /// the write routes take — it used to be `event.type` on the read side
    /// alone, and the two names have been reconciled server-side.
    static let eventMeetingType = Self(entityName: "event", field: "meetingType")
}

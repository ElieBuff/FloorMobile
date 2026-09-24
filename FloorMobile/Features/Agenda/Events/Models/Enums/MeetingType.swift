//
//  MeetingType.swift
//  FloorMobile
//

import Foundation

/// How an appointment is held — the server's `meetingType` (open set). Typed the
/// same way as `Reason` and `EventStatus`: the model keeps the raw string so an
/// unknown value can never break decoding, and this enum is the view of it.
nonisolated enum MeetingType: String, CaseIterable, Sendable {
    case inPerson = "IN_PERSON"
    case videoCall = "VIDEO_CALL"
    case other = "OTHER"

    /// Maps a raw server value, defaulting to `.other` for anything unknown.
    init(raw: String) {
        self = MeetingType(rawValue: raw) ?? .other
    }

    /// What an advisor may pick when booking. `.other` is a landing place for
    /// values the server may add later, not a choice worth offering — nobody
    /// books an "other" appointment on purpose.
    static var selectable: [MeetingType] { [.inPerson, .videoCall] }
}

nonisolated extension MeetingType {
    /// "In store" rather than a mechanical de-underscoring of `IN_PERSON`: the
    /// advisor's word for it is the shop, not the person.
    var displayLabel: String {
        switch self {
        case .inPerson: String(localized: "In store")
        case .videoCall: String(localized: "Video call")
        case .other: String(localized: "Other")
        }
    }
}

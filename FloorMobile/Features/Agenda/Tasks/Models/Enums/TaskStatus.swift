//
//  TaskStatus.swift
//  FloorMobile
//

import SwiftUI

/// Where a task stands — the API's `status` for a task (open set). Typed the
/// same way as `EventStatus` and `Reason`: the model keeps the raw string so an
/// unknown value can never break decoding, and this enum is the view of it.
///
/// Its counterpart on the event side is `EventStatus`, and the two vocabularies
/// are **not** the same list. A task is never "planned" or "confirmed" — it is
/// to do, done, or dropped.
nonisolated enum TaskStatus: String, CaseIterable, Sendable {
    case toDo = "TO_DO"
    case completed = "COMPLETED"
    /// One L. The server spells a task's cancellation `CANCELED` and an
    /// event's `CANCELLED`. Not a typo on this side, and not one to "fix" —
    /// `TaskStatusTests` pins both spellings for that reason.
    case canceled = "CANCELED"
    case other = "OTHER"

    /// Maps a raw server value, defaulting to `.other` for anything unknown.
    init(raw: String) {
        self = TaskStatus(rawValue: raw) ?? .other
    }

    /// What the server files a new task under.
    static let initial = TaskStatus.toDo

    /// What an advisor may move a task to. `.other` is where values this build
    /// does not know land, not a state anyone chooses — the same rule as
    /// `Reason.selectable`.
    static var selectable: [TaskStatus] { allCases.filter { $0 != .other } }

    /// The statuses a day's list shows: what is left to do, and what was done.
    /// A cancelled task is not work any more, so it leaves the day rather than
    /// sitting in it greyed out — where a completed one stays, as the proof the
    /// work happened.
    ///
    /// An allow-list, so a status this build has never heard of is left out
    /// too. That is the one place in the agenda where an unknown server value
    /// is dropped rather than carried: a row whose state nobody can read is a
    /// row whose tick would lie.
    static let listed: [TaskStatus] = [.toDo, .completed]

    /// What tapping a row's tick moves to: what was done goes back to being
    /// to-do, anything else becomes done.
    ///
    /// The tick is a two-state control over a four-state vocabulary, and this
    /// is where that shortcut is written down rather than left in the view.
    var toggled: TaskStatus {
        self == .completed ? .toDo : .completed
    }
}

/// SwiftUI-facing display for each `TaskStatus`: how it reads and which mark
/// it wears.
extension TaskStatus {
    var displayLabel: String {
        switch self {
        case .toDo: String(localized: "To do")
        case .completed: String(localized: "Completed")
        case .canceled: String(localized: "Canceled")
        case .other: String(localized: "Other")
        }
    }

    /// Outlined, not filled: the ring is the same in all three states and only
    /// what sits inside it changes, so the control reads as one object rather
    /// than as three unrelated icons.
    var symbolName: String {
        switch self {
        case .toDo: "circle"
        case .completed: "checkmark.circle"
        case .canceled: "xmark.circle"
        case .other: "questionmark.circle"
        }
    }
}

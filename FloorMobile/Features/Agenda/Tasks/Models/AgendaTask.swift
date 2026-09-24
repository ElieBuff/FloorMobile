//
//  AgendaTask.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// A task in the sales associate's agenda (a call to make, a follow-up, etc.).
///
/// Named `AgendaTask` (not `Task`) to avoid clashing with Swift concurrency's
/// `Task`. Local-first: rows are synced from the API and read by the views
/// through `@Query`. `nonisolated` so a background import can run off the main
/// actor.
@Model
nonisolated final class AgendaTask: Syncable {
    @Attribute(.unique) var id: String
    /// Per-sync generation marker (mark-and-sweep); not from the API.
    var syncToken: String = ""

    /// Rows the latest refresh did not return (see `Syncable`).
    static func stale(token: String) -> Predicate<AgendaTask> {
        #Predicate { $0.syncToken != token }
    }

    /// Raw server values (open sets, e.g. "TO_DO" / "BIRTHDAY"): kept raw.
    var statusRaw: String
    var reasonRaw: String
    var title: String
    var taskDescription: String?
    var startDate: Date
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date

    /// The client, store and sales associate this task concerns, as embedded
    /// display snapshots.
    var client: ClientSummary?
    var store: StoreSummary?
    var salesAssociate: SalesAssociateSummary?

    init(
        id: String,
        statusRaw: String,
        reasonRaw: String,
        title: String,
        taskDescription: String? = nil,
        startDate: Date,
        reminderDate: Date? = nil,
        createdAt: Date,
        updatedAt: Date,
        client: ClientSummary? = nil,
        store: StoreSummary? = nil,
        salesAssociate: SalesAssociateSummary? = nil
    ) {
        self.id = id
        self.statusRaw = statusRaw
        self.reasonRaw = reasonRaw
        self.title = title
        self.taskDescription = taskDescription
        self.startDate = startDate
        self.reminderDate = reminderDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.client = client
        self.store = store
        self.salesAssociate = salesAssociate
    }

    /// Typed view of `reasonRaw`; unknown server values map to `.other`.
    var reason: Reason { Reason(raw: reasonRaw) }

    /// Typed view of `statusRaw`; unknown server values map to `.other`.
    var status: TaskStatus { TaskStatus(raw: statusRaw) }

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var clientDisplayName: String? {
        client?.displayName
    }

    /// The day this task is filed under, at midnight — what the calendar dots.
    var agendaDay: Date {
        startDate.startOfDay
    }
}

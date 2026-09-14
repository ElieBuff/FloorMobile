//
//  AgendaEvent.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// An event in the sales associate's agenda (appointment, etc.).
///
/// Named `AgendaEvent` (not `Event`) to stay unambiguous. Local-first: rows are
/// synced from the API in a server-defined window around today and read by the
/// views through `@Query`. `nonisolated` so a background import can run off the
/// main actor.
@Model
nonisolated final class AgendaEvent: Syncable {
    @Attribute(.unique) var id: String
    /// Per-sync generation marker (mark-and-sweep); not from the API.
    var syncToken: String = ""

    /// Rows the latest refresh did not return (see `Syncable`).
    static func stale(token: String) -> Predicate<AgendaEvent> {
        #Predicate { $0.syncToken != token }
    }
    /// Raw server values (open sets, e.g. "PLANNED" / "APPOINTMENT"): kept raw.
    var statusRaw: String
    var typeRaw: String
    var title: String
    var eventDescription: String?
    var startDate: Date
    /// Minutes.
    var duration: Int
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date
    /// The client, store and sales associate this event concerns, as embedded
    /// display snapshots.
    var client: PersonSummary?
    var store: StoreSummary?
    var salesAssociate: PersonSummary?

    init(
        id: String,
        statusRaw: String,
        typeRaw: String,
        title: String,
        eventDescription: String? = nil,
        startDate: Date,
        duration: Int,
        reminderDate: Date? = nil,
        createdAt: Date,
        updatedAt: Date,
        client: PersonSummary? = nil,
        store: StoreSummary? = nil,
        salesAssociate: PersonSummary? = nil
    ) {
        self.id = id
        self.statusRaw = statusRaw
        self.typeRaw = typeRaw
        self.title = title
        self.eventDescription = eventDescription
        self.startDate = startDate
        self.duration = duration
        self.reminderDate = reminderDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.client = client
        self.store = store
        self.salesAssociate = salesAssociate
    }

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var clientDisplayName: String? {
        client?.displayName
    }

    /// Start plus duration — the event's end instant.
    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(duration) * 60)
    }
}

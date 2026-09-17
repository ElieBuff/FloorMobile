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
    var reasonRaw: String
    /// Raw meeting type (open set, e.g. "IN_PERSON" / "VIDEO_CALL"): kept raw.
    var meetingTypeRaw: String?
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
    var client: ClientSummary?
    var store: StoreSummary?
    var salesAssociate: SalesAssociateSummary?

    init(
        id: String,
        statusRaw: String,
        reasonRaw: String,
        meetingTypeRaw: String? = nil,
        title: String,
        eventDescription: String? = nil,
        startDate: Date,
        duration: Int,
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
        self.meetingTypeRaw = meetingTypeRaw
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

    /// Typed view of `reasonRaw`; unknown server values map to `.other`.
    var reason: Reason { Reason(raw: reasonRaw) }

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var clientDisplayName: String? {
        client?.displayName
    }

    /// Start plus duration — the event's end instant.
    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(duration) * 60)
    }

    /// "In 25 min", "In 2 h", or `nil` once the event has already started.
    /// The date is injected — never `Date()` inside the logic — so this
    /// stays testable at any point in time.
    func countdownLabel(from now: Date) -> String? {
        let interval = startDate.timeIntervalSince(now)
        guard interval > 0 else { return nil }
        let minutes = Int((interval / 60).rounded(.up))
        if minutes < 60 {
            return String(localized: "In \(minutes) min")
        }
        let hours = Int((interval / 3600).rounded(.up))
        return String(localized: "In \(hours) h")
    }

    /// Humanized meeting type ("IN_PERSON" → "In Person"), or `nil` when the
    /// server did not send one.
    private var meetingTypeLabel: String? {
        guard let raw = meetingTypeRaw, !raw.isEmpty else { return nil }
        return raw.capitalized.replacingOccurrences(of: "_", with: " ")
    }

    /// "In Person • VIC", joining the meeting type and the client's loyalty
    /// segment, omitting whichever part is absent.
    var meetingSummary: String? {
        let parts = [meetingTypeLabel, client?.segment].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

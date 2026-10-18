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
    /// Raw server values (open sets, e.g. "PLANNED" / "APPOINTMENT"): kept raw.
    var statusRaw: String
    /// `nil` when the server sent no reason — never a stand-in value, since
    /// whatever is stored here is what an edit sends back.
    var reasonRaw: String?
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
        reasonRaw: String? = nil,
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
}

nonisolated extension AgendaEvent {

    // MARK: - Sync

    /// Rows the latest refresh did not return (see `Syncable`).
    static func stale(token: String) -> Predicate<AgendaEvent> {
        #Predicate { $0.syncToken != token }
    }

    // MARK: - Typed views

    /// Typed view of `reasonRaw`, for display: no reason and a reason this
    /// app does not know both read as `.other`. Not for writing back — a draft
    /// reads `reasonRaw`, which keeps the two apart.
    var reason: Reason { reasonRaw.map(Reason.init(raw:)) ?? .other }

    /// Typed view of `statusRaw`; unknown server values map to `.other`.
    var status: EventStatus { EventStatus(raw: statusRaw) }

    /// Typed view of `meetingTypeRaw`; `nil` when the server sent none, and
    /// `.other` for a value this app does not know yet.
    var meetingType: MeetingType? {
        guard let meetingTypeRaw, !meetingTypeRaw.isEmpty else { return nil }
        return MeetingType(raw: meetingTypeRaw)
    }

    // MARK: - Display

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var clientDisplayName: String? {
        client?.displayName
    }

    /// "In Person • VIC", joining the meeting type and the client's loyalty
    /// segment, omitting whichever part is absent. The meeting type's own
    /// wording rather than a de-underscored raw value: one vocabulary, shared
    /// with the picker that sets it.
    var meetingSummary: String? {
        let parts = [meetingType?.displayLabel, client?.segment].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    // MARK: - Time

    /// How an appointment reads at a given instant — the server's status
    /// crossed with the clock.
    ///
    /// Deliberately not the same thing as `EventStatus`: that one is what the
    /// server asserts, this one is what the advisor sees. A `.planned` booking
    /// becomes `.done` on screen when its slot elapses, without its stored
    /// status moving at all.
    enum Standing: Equatable, Sendable {
        /// Still to come, or under way. Shows its duration.
        case upcoming
        case done
        case cancelled

        /// Whether the row recedes into the background. Not a statement about
        /// time: an appointment cancelled for next week dims too. Done and
        /// cancelled look alike; they only differ in the word the card shows.
        var isDimmed: Bool { self != .upcoming }
    }

    /// Start plus duration — the event's end instant.
    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(duration) * 60)
    }

    /// The day this event is filed under, at midnight — what the calendar dots.
    var agendaDay: Date {
        startDate.startOfDay
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

    /// The server's word first, the clock second.
    ///
    /// Cancelled is not finished — the two recede alike but must not read alike.
    /// Completed is finished even if the slot has not elapsed, because the
    /// advisor closed it out early. For everything the server still calls open,
    /// only the clock can tell, since a booking is never moved on its own as the
    /// day goes by.
    ///
    /// On the clock, an event turns past when it **ends**, not when it starts:
    /// the appointment you are currently in would otherwise dim at exactly the
    /// moment it matters most.
    func standing(at now: Date) -> Standing {
        switch status {
        case .cancelled: .cancelled
        case .completed: .done
        case .planned, .confirmed, .other: endDate <= now ? .done : .upcoming
        }
    }

    /// 0…1 — the fraction of the appointment that has elapsed at `now`,
    /// clamped at both ends. `nil` for a slot with no length at all: there is
    /// no inside to be in.
    func progress(at now: Date) -> Double? {
        let length = endDate.timeIntervalSince(startDate)
        guard length > 0 else { return nil }
        let elapsed = now.timeIntervalSince(startDate)
        return min(max(elapsed / length, 0), 1)
    }

    /// The soonest appointment still ahead on the day `now` falls in, or `nil`
    /// when the day has none left — what Home's "next appointment" card shows.
    ///
    /// Judged on the clock at every call, not on the moment the screen was
    /// built: a `@Query` predicate that captured `now` once kept naming an
    /// appointment long after it had started, and never noticed midnight.
    /// The events may span several days — the same-day check is done here,
    /// so the caller's query only has to be wide enough.
    ///
    /// Start included: an appointment starting this very minute is the next
    /// one, not a past one — the same boundary `DayLayout` uses to place the
    /// current-time rule.
    static func next(
        in events: [AgendaEvent],
        at now: Date,
        calendar: Calendar = .current
    ) -> AgendaEvent? {
        events
            .filter { $0.startDate >= now && calendar.isDate($0.startDate, inSameDayAs: now) }
            .min { $0.startDate < $1.startDate }
    }
}

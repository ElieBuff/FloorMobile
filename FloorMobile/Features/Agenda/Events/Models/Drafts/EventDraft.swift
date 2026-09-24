//
//  EventDraft.swift
//  FloorMobile
//

import Foundation

/// An appointment being composed or edited, before anything is sent anywhere.
/// The event counterpart of `TaskDraft`, and there for the same reasons: it is
/// what `EventComposerView` gathers, what `EventRequest` is built from, and it
/// carries the server-owned fields the form does not show (`id`, `status`, an
/// unknown `reason`) so a save cannot erase them.
///
/// Unlike the task form, the reminder *is* a field here — as an offset, which
/// `reminderDate` turns back into the instant the API stores.
nonisolated struct EventDraft: Equatable, Sendable {
    /// The appointment this draft edits, or `nil` when it is a new one — which
    /// is also what decides between a `POST` and a `PUT`.
    var id: String?
    var title = ""
    /// Nothing until the advisor picks one. The API does not require a reason,
    /// so a field nobody answered is sent unanswered rather than guessed at.
    var reason: Reason?
    /// Nothing until the advisor picks one, like `reason`. The model's own
    /// `meetingType` is already optional — the server leaves it unset — so the
    /// form now says the same thing it does.
    var meetingType: MeetingType?
    /// Set once the client picker exists; the name is what the row shows. Not
    /// sent: the picker has no client id to give, and the API takes an id.
    var clientName = ""
    var startDate: Date
    /// Minutes.
    var duration = 60
    /// Minutes before the start, or `nil` for no reminder.
    var reminderOffset: Int? = 30
    var note = ""
    /// Server-owned, carried through untouched: the form has no status field,
    /// and a save must not quietly replan an appointment someone cancelled.
    var status = EventStatus.planned.rawValue
    /// The reason exactly as the server sent it — see `TaskDraft` for why.
    private var serverReasonRaw: String?

    /// Minutes. The spread a shop floor actually books in — quarter, half,
    /// hour, and up in halves from there.
    static let durations = [15, 30, 60, 90, 120]

    /// When an appointment on another day starts by default — near enough to
    /// when a shop opens.
    static let defaultStartHour = 9

    /// The hour a new appointment starts on when nobody has said otherwise:
    /// the next whole hour if `day` is today, 9:00 on any other — a day begins
    /// at midnight, and rounding that up would book 01:00.
    ///
    /// Offered rather than applied: `init(day:)` takes the instant it is given,
    /// so a caller that knows the hour it wants passes it and this is not in
    /// the way. `now` is a parameter so the rule tests without waiting for a
    /// particular time of day.
    static func defaultStart(
        on day: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        guard calendar.isDate(day, inSameDayAs: now) else {
            return calendar.date(
                bySettingHour: defaultStartHour, minute: 0, second: 0, of: day
            ) ?? day
        }
        // Late enough in the evening this lands on tomorrow, which is what
        // "the next hour" means at 23:30.
        return now.nextHour(calendar)
    }

    init(day: Date) {
        self.startDate = day
    }

    /// Seeded from an appointment that already exists.
    init(event: AgendaEvent) {
        self.id = event.id
        self.title = event.title
        self.reason = event.reason
        // Unset stays unset: opening a form must not invent a type the
        // appointment never had, since saving would then write it in.
        self.meetingType = event.meetingType
        self.clientName = event.clientDisplayName ?? ""
        self.startDate = event.startDate
        self.duration = event.duration
        self.reminderOffset = ReminderOffset.minutes(from: event.reminderDate, before: event.startDate)
        self.note = event.eventDescription ?? ""
        self.status = event.statusRaw
        self.serverReasonRaw = event.reasonRaw
    }

    /// When the reminder actually fires, which is what the API stores — the
    /// offset is only how the advisor thinks about it.
    var reminderDate: Date? {
        guard let reminderOffset else { return nil }
        return startDate.addingTimeInterval(-Double(reminderOffset) * 60)
    }

    /// The reason a save sends, or `nil` when nobody picked one — the API does
    /// not require it.
    ///
    /// `.other` is never picked, since the picker does not offer it, so a draft
    /// reading `.other` is one opened on a server value this build cannot name;
    /// that value goes back untouched rather than being flattened to "OTHER".
    var reasonRaw: String? {
        guard let reason else { return serverReasonRaw }
        return reason == .other ? (serverReasonRaw ?? Reason.other.rawValue) : reason.rawValue
    }

    /// The title as it will be sent — see `TaskDraft.trimmedTitle`.
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The note as it will be sent, or `nil` when there is nothing in it.
    var trimmedNote: String? {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? nil : note
    }

    /// Whether the form can be sent — see `TaskDraft.isValid` for why it is not
    /// called `isComplete`.
    var isValid: Bool {
        !trimmedTitle.isEmpty
    }
}

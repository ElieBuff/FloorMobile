//
//  TaskDraft.swift
//  FloorMobile
//

import Foundation

/// A task being composed or edited, before anything is sent anywhere.
///
/// It gathers what `TaskComposerView` is collecting: the fields write into it,
/// the checkmark in the sheet's toolbar reads `isValid` off it, and the request
/// is built from it (`TaskRequest`).
///
/// Besides the fields the form shows, it carries what the server owns and the
/// form does not offer to edit — `id`, `status`, `reminderDate`. A save sends
/// the whole task back, so anything left out of the draft would be erased by
/// the very act of correcting a title.
///
/// A plain value type, so the rules below can be tested without a view.
nonisolated struct TaskDraft: Equatable, Sendable {
    /// The task this draft edits, or `nil` when it is a new one — which is also
    /// what decides between a `POST` and a `PUT`.
    var id: String?
    var title = ""
    /// Nothing until the advisor picks one. The API does not require a reason,
    /// so a field nobody answered is sent unanswered rather than guessed at.
    var reason: Reason?
    /// Set once the client picker exists; the name is what the row shows. Not
    /// sent: the picker has no client id to give, and the API takes an id.
    var clientName = ""
    var dueDate: Date
    var note = ""
    /// Server-owned, carried through untouched: the form has no status field,
    /// and a save must not quietly reopen a task someone had closed.
    var status = TaskDraft.defaultStatus
    /// Server-owned, carried through untouched: the form has no reminder field
    /// (unlike the event form), so a reminder set elsewhere has to survive it.
    var reminderDate: Date?
    /// The reason exactly as the server sent it, kept because `Reason` lands
    /// every value it does not know on `.other` — and `.other` encodes as
    /// "OTHER". Without this, opening a task whose reason this app has never
    /// heard of and correcting its title would rewrite that reason.
    private var serverReasonRaw: String?

    /// What the server files a new task under.
    static let defaultStatus = TaskStatus.initial.rawValue

    /// Seeded with the day the agenda is showing, so "+" while browsing next
    /// Tuesday does not create something for today.
    init(day: Date) {
        self.dueDate = day
    }

    /// Seeded from a task that already exists, so tapping a row opens the form
    /// on its current values. The optionals fall back to empty strings: the
    /// fields bind to text, and a `nil` has nothing to type into.
    init(task: AgendaTask) {
        self.id = task.id
        self.title = task.title
        self.reason = task.reason
        self.clientName = task.clientDisplayName ?? ""
        self.dueDate = task.startDate
        self.note = task.taskDescription ?? ""
        self.status = task.statusRaw
        self.reminderDate = task.reminderDate
        self.serverReasonRaw = task.reasonRaw
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

    /// The title as it will be sent. `isValid` judges the trimmed form, so what
    /// is saved has to be the same thing that was judged — otherwise the gate
    /// and the payload disagree on what the title is.
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The note as it will be sent, or `nil` when there is nothing in it — an
    /// empty string would be a description nobody wrote.
    var trimmedNote: String? {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? nil : note
    }

    /// Whether the form can be sent. A task with no title is one nobody will
    /// recognise in a list of tasks; everything else has a sensible default, so
    /// this is the only gate.
    ///
    /// Named for the form, not for the task: `complete` is the task's own
    /// vocabulary (`status`), and a draft is never that.
    var isValid: Bool {
        !trimmedTitle.isEmpty
    }
}

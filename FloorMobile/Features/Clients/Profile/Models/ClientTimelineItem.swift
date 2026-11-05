//
//  ClientTimelineItem.swift
//  FloorMobile
//

import Foundation

/// One line of a client's timeline (`ClientTimeline`): a transaction, a
/// conversation, a task or an appointment, with its date, its status and the
/// pieces of its subtitle.
///
/// The server's open sets — the status, a reason, a meeting type — are kept
/// as received, and translated for the view below (Display): by the agenda's
/// enums (`Reason`, `MeetingType`, `TaskStatus`, `EventStatus` — models, not
/// views) for what tasks and appointments carry, by this type's own table for
/// a transaction's or a conversation's status, which the server leaves to the
/// app.
nonisolated struct ClientTimelineItem: Identifiable, Sendable, Equatable {
    /// The server's id of the transaction, conversation, task or appointment.
    let id: String
    let kind: Kind
    /// When it happened or is planned; a conversation's last exchange.
    let date: Date
    /// The raw value, its kind's own (`statusLabel`); `nil` for a transaction
    /// without one.
    let status: String?
    /// Shown as is; `nil` for a transaction naming no product or a
    /// conversation without an associate.
    let title: String?
    /// Joined with " · ", in this order.
    let subtitle: [Part]

    /// What a line is.
    nonisolated enum Kind: String, Sendable {
        case transaction
        case conversation
        case task
        case event
    }

    /// A piece of a line's subtitle.
    nonisolated enum Part: Sendable, Equatable {
        /// How many items a transaction holds, above 0.
        case itemCount(Int)
        /// A transaction's total; `currency` an ISO 4217 code, as the source
        /// gives it.
        case amount(Decimal, currency: String?)
        /// Why a task or an appointment engages the client: a value of
        /// `task.reason` or `event.reason`.
        case reason(String)
        /// How an appointment happens: a value of `event.meetingType`.
        case meetingType(String)
        /// Shown as is: a description, or the start of a conversation's last
        /// message.
        case text(String)
    }
}

/// On the main actor, not `nonisolated` like the line itself: a task's status
/// reads `TaskStatus.displayLabel`, which is — and only views read it.
extension ClientTimelineItem {

    // MARK: - Display

    /// The subtitle as the row shows it: each part translated, joined with
    /// " · ".
    var subtitleText: String {
        subtitle.map(\.displayText).joined(separator: " · ")
    }

    /// The status as the row shows it; `nil` for a line without one, a value
    /// this build does not know, or a kind's catch-all — nothing rather than a
    /// raw code.
    var statusLabel: String? {
        guard let status else { return nil }
        return switch kind {
        case .task:
            switch TaskStatus(raw: status) {
            case .other: nil
            case let known: known.displayLabel
            }
        case .event:
            switch EventStatus(raw: status) {
            case .other: nil
            case let known: known.displayLabel
            }
        case .transaction: Self.transactionStatusLabel(status)
        case .conversation: Self.conversationStatusLabel(status)
        }
    }

    /// A transaction's status: its payment's, or `CANCELLED` (the server's
    /// `FinancialStatus`, plus a cancellation).
    private static func transactionStatusLabel(_ status: String) -> String? {
        switch status {
        case "PENDING": String(localized: "Pending")
        case "PARTIALLY_PAID": String(localized: "Partially paid")
        case "PAID": String(localized: "Paid")
        case "PARTIALLY_REFUNDED": String(localized: "Partially refunded")
        case "REFUNDED": String(localized: "Refunded")
        case "VOIDED": String(localized: "Voided")
        case "CANCELLED": String(localized: "Cancelled")
        default: nil
        }
    }

    /// A conversation's status (the server's `ConversationStatus`).
    private static func conversationStatusLabel(_ status: String) -> String? {
        switch status {
        case "ACTIVE": String(localized: "Active")
        case "ARCHIVED": String(localized: "Archived")
        case "CLOSED": String(localized: "Closed")
        default: nil
        }
    }
}

nonisolated extension ClientTimelineItem.Kind {

    // MARK: - Display

    /// What the line is called when it has no title of its own.
    var displayLabel: String {
        switch self {
        case .transaction: String(localized: "Purchase")
        case .conversation: String(localized: "Conversation")
        case .task: String(localized: "Task")
        case .event: String(localized: "Appointment")
        }
    }

    /// The SF Symbol a row wears for it.
    var symbolName: String {
        switch self {
        case .transaction: "bag"
        case .conversation: "bubble.left.and.bubble.right"
        case .task: "checklist"
        case .event: "calendar"
        }
    }
}

/// On the main actor: a reason reads `Reason.displayLabel`, which is.
extension ClientTimelineItem.Part {

    // MARK: - Display

    /// The part as the subtitle shows it. An amount without a currency is
    /// still a number worth reading.
    var displayText: String {
        switch self {
        case .itemCount(let count): String(localized: "\(count) items")
        case .amount(let amount, let currency?): amount.formatted(.currency(code: currency))
        case .amount(let amount, nil): amount.formatted()
        case .reason(let reason): Reason(raw: reason).displayLabel
        case .meetingType(let meetingType): MeetingType(raw: meetingType).displayLabel
        case .text(let text): text
        }
    }
}

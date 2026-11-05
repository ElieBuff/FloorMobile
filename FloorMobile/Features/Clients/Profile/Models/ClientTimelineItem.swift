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
/// as received: the view translates them through the vocabulary of
/// `GET setup`, as the agenda does.
nonisolated struct ClientTimelineItem: Identifiable, Sendable, Equatable {
    /// The server's id of the transaction, conversation, task or appointment.
    let id: String
    let kind: Kind
    /// When it happened or is planned; a conversation's last exchange.
    let date: Date
    /// The raw value, to translate as `<kind>.status.<value>`; `nil` for a
    /// transaction without one.
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

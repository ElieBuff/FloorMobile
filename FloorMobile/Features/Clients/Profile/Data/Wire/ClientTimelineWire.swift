//
//  ClientTimelineWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of `ClientTimeline`: what `client/{id}/timeline` serves — two
/// lists of lines, what is planned with the client and what happened.
/// Read-only.
///
/// Lenient by design: the server may add a type of line, or of subtitle part,
/// that this build does not know, and the contract says to skip it. So each
/// `type` is a `String` and every field a type may lack is optional; the
/// conversion (`ClientTimeline.init(wire:)`) drops what it cannot read.
nonisolated enum ClientTimelineWire {
    struct Response: Decodable, Sendable {
        /// Every task still to do and every task or appointment from now on,
        /// the earliest first.
        var upcoming: [Item]
        /// Transactions, conversations, tasks done or cancelled and past
        /// appointments, the latest first.
        var past: [Item]
    }

    /// One line: `transaction`, `conversation`, `task` or `event`.
    struct Item: Decodable, Sendable {
        var type: String
        var id: String
        var date: Date
        /// The raw value, translated by the app
        /// (`ClientTimelineItem.statusLabel`); `null` for a transaction
        /// without one.
        var status: String?
        /// Shown as is; `null` for a transaction naming no product or a
        /// conversation without an associate.
        var title: String?
        /// Joined by the app with " · ", in this order.
        var subtitle: [Part]
    }

    /// A piece of a subtitle, by its `type`: `itemCount` (`count`), `amount`
    /// (`amount`, `currency`), `reason`, `meetingType` or `text`.
    struct Part: Decodable, Sendable {
        var type: String
        var count: Int?
        var amount: Decimal?
        /// An ISO 4217 code, as the source gives it.
        var currency: String?
        /// A value of `GET setup`'s `task.reason` or `event.reason`.
        var reason: String?
        /// A value of `GET setup`'s `event.meetingType`.
        var meetingType: String?
        var text: String?
    }
}

nonisolated extension ClientTimeline {
    /// Maps the wire format into the timeline, in the server's order; a line
    /// or a part this build cannot read is left out.
    init(wire: ClientTimelineWire.Response) {
        self.init(
            upcoming: wire.upcoming.compactMap(ClientTimelineItem.init(wire:)),
            past: wire.past.compactMap(ClientTimelineItem.init(wire:))
        )
    }
}

nonisolated extension ClientTimelineItem {
    /// A line of a known type, its parts this build can read; `nil` for a
    /// line of another type.
    init?(wire: ClientTimelineWire.Item) {
        guard let kind = Kind(rawValue: wire.type) else { return nil }
        self.init(
            id: wire.id,
            kind: kind,
            date: wire.date,
            status: wire.status,
            title: wire.title,
            subtitle: wire.subtitle.compactMap(Part.init(wire:))
        )
    }
}

nonisolated extension ClientTimelineItem.Part {
    /// A part of a known type carrying what that type needs; `nil` otherwise.
    init?(wire: ClientTimelineWire.Part) {
        switch wire.type {
        case "itemCount":
            guard let count = wire.count else { return nil }
            self = .itemCount(count)
        case "amount":
            guard let amount = wire.amount else { return nil }
            self = .amount(amount, currency: wire.currency)
        case "reason":
            guard let reason = wire.reason else { return nil }
            self = .reason(reason)
        case "meetingType":
            guard let meetingType = wire.meetingType else { return nil }
            self = .meetingType(meetingType)
        case "text":
            guard let text = wire.text else { return nil }
            self = .text(text)
        default:
            return nil
        }
    }
}

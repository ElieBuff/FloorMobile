//
//  EventWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of an agenda event: what the API serves, and what the app sends
/// back. Two types, not one `Codable`: the read half carries server-owned
/// fields (`id`, timestamps, the nested people and store) that the strict write
/// schemas reject, and its optionals mean "the server has nothing" where the
/// write half's mean "leave the key out".
nonisolated enum EventWire {
    /// An event exactly as the API serves it.
    ///
    /// A wire type is justified here (the rule is "no systematic DTOs"): the
    /// nested people and store objects are flattened into the local model.
    struct Response: Decodable, Sendable {
        var id: String
        var status: String
        var reason: String?
        var meetingType: String?
        var title: String
        var description: String?
        var startDate: Date
        var duration: Int
        var reminderDate: Date?
        var createdAt: Date
        var updatedAt: Date
        var client: ClientSummaryWire?
        var store: StoreWire?
        var salesAssociate: SalesAssociateWire?
    }

    /// What the app sends to book or replace an appointment. Its own type rather
    /// than an `Encodable` draft, for the reasons `TaskWire.Request` sets out.
    ///
    /// The optionals are `nil` rather than empty, so `JSONEncoder` drops the keys
    /// instead of sending `null`. `clientId` is absent entirely: `ClientPickerView`
    /// holds a name, not an id, until the Clients feature lands.
    /// There is no `type` here, and there must not be: `createEventSchema` and
    /// `updateEventSchema` are `.strict()` and declare `meetingType` alone, so a
    /// spare `type` key is a rejected request rather than an ignored one: the
    /// vocabulary (`GET setup`) publishes the field as `event.meetingType` too.
    struct Request: Encodable, Sendable {
        var title: String
        var status: String
        var startDate: Date
        var description: String?
        /// Minutes.
        var duration: Int
        var reminderDate: Date?
        /// Absent when nobody picked one — same rule as `reason`.
        var meetingType: String?
        /// Absent when nobody picked one: the optional makes `JSONEncoder` drop the
        /// key rather than send `null`, which is what the schema expects of a field
        /// it does not require.
        var reason: String?

        /// Built from what the form gathered, including the fields it does not show
        /// (`status`, an unknown `reason`) — a `PUT` replaces the whole event, so
        /// leaving one out would erase it.
        init(draft: EventDraft) {
            title = draft.trimmedTitle
            status = draft.status
            startDate = draft.startDate
            description = draft.trimmedNote
            duration = draft.duration
            reminderDate = draft.reminderDate
            meetingType = draft.meetingType?.rawValue
            reason = draft.reasonRaw
        }
    }
}

nonisolated extension AgendaEvent {
    /// Maps the wire format into the local model, flattening the nested people
    /// and store.
    convenience init(wire: EventWire.Response) {
        self.init(
            id: wire.id,
            statusRaw: wire.status,
            reasonRaw: wire.reason,
            meetingTypeRaw: wire.meetingType,
            title: wire.title,
            eventDescription: wire.description,
            startDate: wire.startDate,
            duration: wire.duration,
            reminderDate: wire.reminderDate,
            createdAt: wire.createdAt,
            updatedAt: wire.updatedAt,
            client: wire.client.map(ClientSummary.init(wire:)),
            store: wire.store.map(StoreSummary.init(wire:)),
            salesAssociate: wire.salesAssociate.map(SalesAssociateSummary.init(wire:))
        )
    }
}

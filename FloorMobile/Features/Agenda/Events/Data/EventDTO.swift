//
//  EventDTO.swift
//  FloorMobile
//

import Foundation

/// Wire format of an agenda event, exactly as the API serves it.
///
/// A DTO is justified here (the rule is "no systematic DTOs"): the nested
/// people and store objects are flattened into the local model.
nonisolated struct EventDTO: Decodable, Sendable {
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
    var client: ClientSummary?
    var store: StoreDTO?
    var salesAssociate: SalesAssociateSummary?
}

/// What the app sends to book or replace an appointment — the write half of
/// the event's wire format, `EventDTO` being the read half. Its own type rather
/// than an `Encodable` draft, for the reasons `TaskRequest` sets out.
///
/// The optionals are `nil` rather than empty, so `JSONEncoder` drops the keys
/// instead of sending `null`. `clientId` is absent entirely: `ClientPickerView`
/// holds a name, not an id, until the Clients feature lands.
/// There is no `type` here, and there must not be: `createEventSchema` and
/// `updateEventSchema` are `.strict()` and declare `meetingType` alone, so a
/// spare `type` key is a rejected request rather than an ignored one. The app
/// used to send both, back when `GET enums` published the vocabulary under
/// `event.type` — the server has since reconciled the two names on
/// `meetingType`, and this is the only name left.
nonisolated struct EventRequest: Encodable, Sendable {
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

nonisolated extension AgendaEvent {
    /// Maps the wire format into the local model, flattening the nested people
    /// and store.
    convenience init(dto: EventDTO) {
        self.init(
            id: dto.id,
            statusRaw: dto.status,
            reasonRaw: dto.reason ?? Reason.other.rawValue,
            meetingTypeRaw: dto.meetingType,
            title: dto.title,
            eventDescription: dto.description,
            startDate: dto.startDate,
            duration: dto.duration,
            reminderDate: dto.reminderDate,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            client: dto.client,
            store: dto.store.map(StoreSummary.init(dto:)),
            salesAssociate: dto.salesAssociate
        )
    }
}

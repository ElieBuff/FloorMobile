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

//
//  TaskDTO.swift
//  FloorMobile
//

import Foundation

/// Wire format of an agenda task, exactly as the API serves it. Same shape as
/// `EventDTO` minus `duration`.
nonisolated struct TaskDTO: Decodable, Sendable {
    var id: String
    var status: String
    var reason: String?
    var title: String
    var description: String?
    var startDate: Date
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var client: ClientSummary?
    var store: StoreDTO?
    var salesAssociate: SalesAssociateSummary?
}

nonisolated extension AgendaTask {
    /// Maps the wire format into the local model, flattening the nested people
    /// and store.
    convenience init(dto: TaskDTO) {
        self.init(
            id: dto.id,
            statusRaw: dto.status,
            reasonRaw: dto.reason ?? Reason.other.rawValue,
            title: dto.title,
            taskDescription: dto.description,
            startDate: dto.startDate,
            reminderDate: dto.reminderDate,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            client: dto.client,
            store: dto.store.map(StoreSummary.init(dto:)),
            salesAssociate: dto.salesAssociate
        )
    }
}

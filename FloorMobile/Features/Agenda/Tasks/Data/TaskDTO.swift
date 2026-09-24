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

/// What the app sends to create or replace a task — the write half of the
/// task's wire format, `TaskDTO` being the read half. A type of its own rather
/// than an `Encodable` draft: two of its fields do not map one-to-one onto the
/// form (`description`, `startDate`), and the form has no business knowing the
/// server's field names.
///
/// The optionals are `nil` rather than empty, so `JSONEncoder` drops the keys
/// instead of sending `null` — a null reads as an instruction to clear a value,
/// which is not what an untouched field means.
///
/// `clientId` is absent entirely: `ClientPickerView` holds a name, not an id,
/// until the Clients feature lands.
///
/// There is no `type` here. The task routes have no such field — it appears in
/// neither the read payload nor `GET enums` — and the route's schema is strict,
/// so a key the app made up is a rejected request.
nonisolated struct TaskRequest: Encodable, Sendable {
    /// Absent when nobody picked one: the optional makes `JSONEncoder` drop the
    /// key rather than send `null`, which is what the schema expects of a field
    /// it does not require.
    var reason: String?
    var title: String
    var status: String
    var startDate: Date
    var description: String?
    var reminderDate: Date?

    /// Built from what the form gathered, including the fields it does not show
    /// (`status`, `reminderDate`) — a `PUT` replaces the whole task, so leaving
    /// one out would erase it.
    init(draft: TaskDraft) {
        reason = draft.reasonRaw
        title = draft.trimmedTitle
        status = draft.status
        startDate = draft.dueDate
        description = draft.trimmedNote
        reminderDate = draft.reminderDate
    }
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

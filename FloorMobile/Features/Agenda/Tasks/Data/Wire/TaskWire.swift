//
//  TaskWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of an agenda task: what the API serves, and what the app sends
/// back. Split in two for the reasons `EventWire` sets out.
nonisolated enum TaskWire {
    /// A task exactly as the API serves it. Same shape as
    /// `EventWire.Response` minus `duration`.
    struct Response: Decodable, Sendable {
        var id: String
        var status: String
        var reason: String?
        var title: String
        var description: String?
        var startDate: Date
        var reminderDate: Date?
        var createdAt: Date
        var updatedAt: Date
        var client: ClientSummaryWire?
        var store: StoreWire?
        var salesAssociate: SalesAssociateWire?
    }

    /// What the app sends to create or replace a task. A type of its own rather
    /// than an `Encodable` draft: two of its fields do not map one-to-one onto
    /// the form (`description`, `startDate`), and the form has no business
    /// knowing the server's field names.
    ///
    /// The optionals are `nil` rather than empty, so `JSONEncoder` drops the keys
    /// instead of sending `null` — a null reads as an instruction to clear a value,
    /// which is not what an untouched field means.
    ///
    /// `clientId` is absent entirely: `ClientPickerView` holds a name, not an id,
    /// until the Clients feature lands.
    ///
    /// There is no `type` here. The task routes have no such field — it appears in
    /// neither the read payload nor the vocabulary (`GET setup`) — and the route's schema is strict,
    /// so a key the app made up is a rejected request.
    struct Request: Encodable, Sendable {
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
}

nonisolated extension AgendaTask {
    /// Maps the wire format into the local model, flattening the nested people
    /// and store.
    convenience init(wire: TaskWire.Response) {
        self.init(
            id: wire.id,
            statusRaw: wire.status,
            reasonRaw: wire.reason,
            title: wire.title,
            taskDescription: wire.description,
            startDate: wire.startDate,
            reminderDate: wire.reminderDate,
            createdAt: wire.createdAt,
            updatedAt: wire.updatedAt,
            client: wire.client.map(ClientSummary.init(wire:)),
            store: wire.store.map(StoreSummary.init(wire:)),
            salesAssociate: wire.salesAssociate.map(SalesAssociateSummary.init(wire:))
        )
    }
}

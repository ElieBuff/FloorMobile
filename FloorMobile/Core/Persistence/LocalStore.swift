//
//  LocalStore.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// What the device's SwiftData store holds, and how to empty it.
///
/// The rows live in SwiftData; what describes them — whose they are, how far
/// they go — lives here, beside them, so that a wipe takes both. A marker that
/// outlived its rows would lie about them: the client cursor, for one, would
/// ask only for recent changes on a store that holds no client.
///
/// Single-tenant isolation is enforced here: when the active tenant differs
/// from the one the store holds, everything is erased before any data is
/// shown. Combined with the logout wipe, a tenant's data can never surface
/// under another. Rows are not tagged — isolation lives in the context.
nonisolated struct LocalStore: Sendable {
    /// The tenant the store currently holds.
    var tenantID: StoredValue<String>
    /// Where the store's client sync resumes from — see `ClientService`.
    var clientCursor: StoredValue<String>

    /// Erases the store when `currentTenantID` is not the tenant it holds, and
    /// records the new one.
    @MainActor
    func enforceTenant(_ currentTenantID: String?, context: ModelContext) throws {
        guard currentTenantID != tenantID.get() else { return }
        try erase(in: context)
        tenantID.set(currentTenantID)
    }

    /// Erases every row instead of calling `container.deleteAllData()`.
    ///
    /// That call resets the store underneath every `ModelContext` that already
    /// exists — including the ones the `@ModelActor` services build at launch
    /// and keep for the life of the app. The next write through one of them
    /// trips a SwiftData assertion and aborts the process. Deleting rows
    /// leaves those contexts valid.
    ///
    /// The list mirrors `FloorSchemaV1.models`: `delete(model:)` needs a
    /// concrete type, so it cannot be derived from the schema. `LocalStoreTests`
    /// fails if a model is added there and forgotten here.
    ///
    /// The client sync cursor goes too: it says which clients the store
    /// already holds, and after this it holds none. Left behind, the next sync
    /// would ask only for recent changes and leave the store all but empty.
    @MainActor
    func erase(in context: ModelContext) throws {
        try context.delete(model: AIAction.self)
        try context.delete(model: AgendaEvent.self)
        try context.delete(model: AgendaTask.self)
        try context.delete(model: Client.self)
        try context.delete(model: ClientFilter.self)
        try context.delete(model: EnumValue.self)
        try context.delete(model: RecentClient.self)
        try context.save()
        clientCursor.set(nil)
    }

    static let live = LocalStore(
        tenantID: .userDefaults(.lastTenantID),
        clientCursor: .userDefaults(.clientSyncCursor)
    )
}

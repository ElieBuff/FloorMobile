//
//  LocalStore.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// What the device's SwiftData store holds, and how to empty it.
///
/// The rows live in SwiftData; what describes them — whose they are — lives
/// here, beside them: a marker that outlived its rows would lie about them.
///
/// Single-tenant isolation is enforced here: when the active tenant differs
/// from the one the store holds, everything is erased before any data is
/// shown. Combined with the logout wipe, a tenant's data can never surface
/// under another. Rows are not tagged — isolation lives in the context.
nonisolated struct LocalStore: Sendable {
    /// The tenant the store currently holds.
    var tenantID: StoredValue<String>

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
    /// Rows only: no stored value describes them today. `tenantID` is written
    /// by `enforceTenant` right after, and the associate signed in is
    /// `AppSession`'s to keep and clear. A marker that came to describe the
    /// rows — a sync cursor, say — would be wiped here with them.
    @MainActor
    func erase(in context: ModelContext) throws {
        try context.delete(model: AIAction.self)
        try context.delete(model: AgendaEvent.self)
        try context.delete(model: AgendaTask.self)
        try context.delete(model: ClientFilter.self)
        try context.delete(model: ClientSegment.self)
        try context.delete(model: ClientSort.self)
        try context.delete(model: EnumValue.self)
        try context.save()
    }

    static let live = LocalStore(tenantID: .userDefaults(.lastTenantID))
}

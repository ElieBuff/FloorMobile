//
//  TenantGuard.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// Enforces single-tenant isolation on the local store: when the active tenant
/// differs from the one the store currently holds, it erases everything before
/// any data is shown. Combined with the logout wipe, a tenant's data can never
/// surface under another. Rows are not tagged — isolation lives in the context.
nonisolated struct TenantGuard: Sendable {
    var lastTenantID: @Sendable () -> String?
    var setLastTenantID: @Sendable (String?) -> Void

    @MainActor
    func enforce(currentTenantID: String?, context: ModelContext) throws {
        guard currentTenantID != lastTenantID() else { return }
        try Self.erase(in: context)
        setLastTenantID(currentTenantID)
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
    /// concrete type, so it cannot be derived from the schema. `TenantGuardTests`
    /// fails if a model is added there and forgotten here.
    @MainActor
    static func erase(in context: ModelContext) throws {
        try context.delete(model: AIAction.self)
        try context.delete(model: AgendaEvent.self)
        try context.delete(model: AgendaTask.self)
        try context.delete(model: FieldOption.self)
        try context.save()
    }

    static let live = TenantGuard(
        lastTenantID: { UserDefaults.standard.string(forKey: key) },
        setLastTenantID: { newValue in
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    )

    private static let key = "lastTenantID"
}

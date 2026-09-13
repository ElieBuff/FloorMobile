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
    func enforce(currentTenantID: String?, context: ModelContext) {
        guard currentTenantID != lastTenantID() else { return }
        context.container.deleteAllData()
        setLastTenantID(currentTenantID)
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

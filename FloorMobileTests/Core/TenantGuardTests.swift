//
//  TenantGuardTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Tenant guard")
@MainActor
struct TenantGuardTests {

    /// In-memory marker the test can inspect. `@unchecked Sendable` is safe
    /// here: the suite is MainActor-confined and single-threaded.
    private final class Marker: @unchecked Sendable {
        var value: String?
        init(_ value: String?) { self.value = value }
    }

    private func makeGuard(backedBy marker: Marker) -> TenantGuard {
        TenantGuard(
            lastTenantID: { marker.value },
            setLastTenantID: { marker.value = $0 }
        )
    }

    private func seededContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AIAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(AIAction(id: "x", agentKey: "a", type: "t", title: "t",
                                reason: "r", statusRaw: "PENDING", createdAt: Date(timeIntervalSince1970: 0)))
        try context.save()
        return context
    }

    @Test("Same tenant keeps the store and the marker")
    func sameTenantKeepsStore() throws {
        let context = try seededContext()
        let marker = Marker("org-1")

        makeGuard(backedBy: marker).enforce(currentTenantID: "org-1", context: context)

        #expect(try context.fetch(FetchDescriptor<AIAction>()).count == 1)
        #expect(marker.value == "org-1")
    }

    @Test("A different tenant wipes the store and updates the marker")
    func differentTenantWipesStore() throws {
        let context = try seededContext()
        let marker = Marker("org-1")

        makeGuard(backedBy: marker).enforce(currentTenantID: "org-2", context: context)

        #expect(try context.fetch(FetchDescriptor<AIAction>()).isEmpty)
        #expect(marker.value == "org-2")
    }

    @Test("First login (no previous tenant) records the tenant")
    func firstLoginRecordsTenant() throws {
        let context = try seededContext()
        let marker = Marker(nil)

        makeGuard(backedBy: marker).enforce(currentTenantID: "org-1", context: context)

        #expect(try context.fetch(FetchDescriptor<AIAction>()).isEmpty)
        #expect(marker.value == "org-1")
    }
}

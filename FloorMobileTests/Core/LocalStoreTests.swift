//
//  LocalStoreTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Local store")
@MainActor
struct LocalStoreTests {

    private func makeStore(
        tenant: StoredValue<String>,
        cursor: StoredValue<String> = .inMemory()
    ) -> LocalStore {
        LocalStore(tenantID: tenant, clientCursor: cursor)
    }

    /// A store holding one row of **every** model in the schema.
    ///
    /// One row per model on purpose: `LocalStore.erase` names its types one
    /// by one (`delete(model:)` needs a concrete type), so a model added to
    /// `FloorSchemaV1` and forgotten there would leak a tenant's rows into the
    /// next session. `wipedRowCount` below turns that into a failing test.
    private func seededContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AIAction.self, AgendaEvent.self, AgendaTask.self, Client.self, FieldOption.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let epoch = Date(timeIntervalSince1970: 0)
        context.insert(AIAction(id: "x", agentKey: "a", type: "t", title: "t",
                                reason: "r", statusRaw: "PENDING", createdAt: epoch))
        context.insert(AgendaEvent(id: "e", statusRaw: "PLANNED", reasonRaw: "FOLLOW_UP",
                                   title: "e", startDate: epoch, duration: 30,
                                   createdAt: epoch, updatedAt: epoch))
        context.insert(AgendaTask(id: "t", statusRaw: "TO_DO", reasonRaw: "FOLLOW_UP",
                                  title: "t", startDate: epoch,
                                  createdAt: epoch, updatedAt: epoch))
        context.insert(Client(id: "c", externalId: "c"))
        context.insert(FieldOption(entityName: "task", field: "reason", value: "CALL", rank: 0))
        try context.save()
        return context
    }

    /// How many rows survive the wipe, across every model of the schema.
    private func remainingRowCount(in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<AIAction>())
            + context.fetchCount(FetchDescriptor<AgendaEvent>())
            + context.fetchCount(FetchDescriptor<AgendaTask>())
            + context.fetchCount(FetchDescriptor<Client>())
            + context.fetchCount(FetchDescriptor<FieldOption>())
    }

    @Test("Same tenant keeps the store and the marker")
    func sameTenantKeepsStore() throws {
        let context = try seededContext()
        let tenant = StoredValue<String>.inMemory("org-1")
        let cursor = StoredValue<String>.inMemory("cursor")

        try makeStore(tenant: tenant, cursor: cursor).enforceTenant("org-1", context: context)

        #expect(try remainingRowCount(in: context) == 5)
        #expect(tenant.get() == "org-1")
        #expect(cursor.get() == "cursor")
    }

    @Test("A different tenant wipes every model and updates the marker")
    func differentTenantWipesStore() throws {
        let context = try seededContext()
        let tenant = StoredValue<String>.inMemory("org-1")
        let cursor = StoredValue<String>.inMemory("cursor")

        try makeStore(tenant: tenant, cursor: cursor).enforceTenant("org-2", context: context)

        // Not a single row of any model survives: this is what keeps one
        // tenant's data from surfacing under another.
        #expect(try remainingRowCount(in: context) == 0)
        #expect(tenant.get() == "org-2")
        // Nor the client cursor: kept, it would ask the new tenant's server
        // for recent changes only, on a store that now holds no client.
        #expect(cursor.get() == nil)
    }

    @Test("First login (no previous tenant) records the tenant")
    func firstLoginRecordsTenant() throws {
        let context = try seededContext()
        let tenant = StoredValue<String>.inMemory()

        try makeStore(tenant: tenant).enforceTenant("org-1", context: context)

        #expect(try remainingRowCount(in: context) == 0)
        #expect(tenant.get() == "org-1")
    }

    @Test("The wipe leaves the context usable, so the sync that follows can write")
    func contextStaysUsableAfterTheWipe() throws {
        let context = try seededContext()

        try makeStore(tenant: .inMemory("org-1")).enforceTenant("org-2", context: context)

        // The regression this guards against: `container.deleteAllData()` used
        // to reset the store under every live context, and the startup sync
        // aborted the process on its first write afterwards.
        context.insert(FieldOption(entityName: "task", field: "reason", value: "AFTER", rank: 0))
        try context.save()

        #expect(try context.fetch(FetchDescriptor<FieldOption>()).map(\.value) == ["AFTER"])
    }
}

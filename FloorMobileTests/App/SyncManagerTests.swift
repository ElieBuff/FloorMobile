//
//  SyncManagerTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Startup sync")
@MainActor
struct SyncManagerTests {

    @Test("A successful startup sync stores the configuration and opens the app")
    func finishesAndPersists() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(localStore: Self.store(tenant: .inMemory("org-1")))
        var kept: (associate: SalesAssociateSnapshot?, store: StoreSnapshot?)?

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.serving(),
            keepSignedInAssociate: { kept = ($0, $1) }
        )

        #expect(manager.state == .finished)
        // The real setup's associate and store, handed on to the session.
        #expect(kept?.associate?.firstName == "Elie")
        #expect(kept?.store?.storeCode == "90917634296")
        let options = try ModelContext(container).fetch(FetchDescriptor<EnumValue>())
        let valueCount = try Fixture.enumsValueCount()
        #expect(options.count == valueCount)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ClientFilter>()) == 2)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ClientSort>()) == 6)
    }

    @Test("A failure with nothing in store stops on the loading screen, and hands nothing on to the session")
    func coldFailureBlocks() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(localStore: Self.store(tenant: .inMemory("org-1")))
        var keptCalled = false

        // `setup` is all the launch asks for, and it must not treat it as
        // optional: the pickers need it.
        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.failing(),
            keepSignedInAssociate: { _, _ in keptCalled = true }
        )

        guard case .failed = manager.state else {
            Issue.record("Expected .failed, got \(manager.state)")
            return
        }
        // No setup, nothing handed on: the session keeps the associate it had.
        #expect(!keptCalled)
    }

    @Test("A failure with data from an earlier run opens the app anyway")
    func warmFailureOpensOnCache() async throws {
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            EnumValue(entityName: "task", field: "reason", value: "CACHED", rank: 0)
        )
        try container.mainContext.save()
        // The vocabulary of an earlier run is all the launch needs to open.
        let manager = SyncManager(localStore: Self.store(tenant: .inMemory("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.failing(),
            keepSignedInAssociate: { _, _ in }
        )

        // Offline in the shop: the advisor keeps what the last sync brought.
        #expect(manager.state == .finished)
        let values = try ModelContext(container).fetch(FetchDescriptor<EnumValue>()).map(\.value)
        #expect(values == ["CACHED"])
    }

    // This one aborted the whole process while the wipe still went through
    // `container.deleteAllData()`: the sync that follows writes via contexts
    // the services built at launch, which that call invalidates. It passes
    // now that `LocalStore.erase` deletes rows instead — keep it.
    @Test("A tenant change wipes the store before anything is shown")
    func tenantChangeWipesFirst() async throws {
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            EnumValue(entityName: "task", field: "reason", value: "OTHER_TENANT", rank: 0)
        )
        try container.mainContext.save()
        let tenant = StoredValue<String>.inMemory("org-1")
        let manager = SyncManager(localStore: Self.store(tenant: tenant))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-2",
            services: AppServices(container: container),
            api: Self.serving(),
            keepSignedInAssociate: { _, _ in }
        )

        // The previous tenant's rows are gone, replaced by the new sync only.
        let values = try ModelContext(container).fetch(FetchDescriptor<EnumValue>()).map(\.value)
        #expect(!values.contains("OTHER_TENANT"))
        #expect(tenant.get() == "org-2")
    }

    /// A sign-out leaves the manager `.finished`, which would send the next
    /// sign-in straight into the app on a store `LocalStore` just emptied.
    @Test("Resetting sends the next sign-in back through the sync")
    func resetReturnsToIdle() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(localStore: Self.store(tenant: .inMemory("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.serving(),
            keepSignedInAssociate: { _, _ in }
        )
        #expect(manager.state == .finished)

        manager.reset()

        #expect(manager.state == .idle)
    }

    // MARK: - Helpers

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AIAction.self, AgendaEvent.self, AgendaTask.self, ClientFilter.self, ClientSegment.self,
            ClientSort.self, EnumValue.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private static func store(tenant: StoredValue<String>) -> LocalStore {
        LocalStore(tenantID: tenant)
    }

    /// The startup's one route answered: the configuration.
    private nonisolated static func serving() -> APIClient {
        client { request in (response(request, statusCode: 200), try Fixture.data("setup")) }
    }

    /// Every route down.
    private nonisolated static func failing() -> APIClient {
        client { request in (response(request, statusCode: 500), Data()) }
    }

    private nonisolated static func client(handler: @escaping MockURLProtocol.Handler) -> APIClient {
        APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            tokens: TokenProviding(
                validToken: { "valid-token" },
                refreshedToken: { "refreshed-token" }
            ),
            session: MockURLProtocol.session(handler: handler)
        )
    }

    private nonisolated static func response(_ request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://invalid")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

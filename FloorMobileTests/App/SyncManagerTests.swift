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

    @Test("A successful startup sync stores the vocabulary and the clients, and opens the app")
    func finishesAndPersists() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(localStore: Self.store(tenant: .inMemory("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.serving()
        )

        #expect(manager.state == .finished)
        let options = try ModelContext(container).fetch(FetchDescriptor<FieldOption>())
        let valueCount = try Fixture.enumsValueCount()
        #expect(options.count == valueCount)
        let clients = try ModelContext(container).fetchCount(FetchDescriptor<Client>())
        #expect(clients == 3)
    }

    @Test("A failure with nothing in store stops on the loading screen")
    func coldFailureBlocks() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(localStore: Self.store(tenant: .inMemory("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.failing()
        )

        guard case .failed = manager.state else {
            Issue.record("Expected .failed, got \(manager.state)")
            return
        }
    }

    @Test("A failure with data from an earlier run opens the app anyway")
    func warmFailureOpensOnCache() async throws {
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            FieldOption(entityName: "task", field: "reason", value: "CACHED", rank: 0)
        )
        try container.mainContext.save()
        // A complete client pass went through on that earlier run.
        let manager = SyncManager(localStore: Self.store(
            tenant: .inMemory("org-1"), cursor: .inMemory("cursor-pass-1")
        ))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.failing()
        )

        // Offline in the shop: the advisor keeps what the last sync brought.
        #expect(manager.state == .finished)
        let values = try ModelContext(container).fetch(FetchDescriptor<FieldOption>()).map(\.value)
        #expect(values == ["CACHED"])
    }

    @Test("A failure before any client pass completed stops on the loading screen")
    func failureWithoutClientsBlocks() async throws {
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            FieldOption(entityName: "task", field: "reason", value: "CACHED", rank: 0)
        )
        try container.mainContext.save()
        // The vocabulary is there, but no client pass has ever finished.
        let manager = SyncManager(localStore: Self.store(tenant: .inMemory("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.failing()
        )

        guard case .failed = manager.state else {
            Issue.record("Expected .failed, got \(manager.state)")
            return
        }
    }

    // This one aborted the whole process while the wipe still went through
    // `container.deleteAllData()`: the sync that follows writes via contexts
    // the services built at launch, which that call invalidates. It passes
    // now that `LocalStore.erase` deletes rows instead — keep it.
    @Test("A tenant change wipes the store before anything is shown")
    func tenantChangeWipesFirst() async throws {
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            FieldOption(entityName: "task", field: "reason", value: "OTHER_TENANT", rank: 0)
        )
        try container.mainContext.save()
        let tenant = StoredValue<String>.inMemory("org-1")
        let manager = SyncManager(localStore: Self.store(tenant: tenant))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-2",
            services: AppServices(container: container),
            api: Self.serving()
        )

        // The previous tenant's rows are gone, replaced by the new sync only.
        let values = try ModelContext(container).fetch(FetchDescriptor<FieldOption>()).map(\.value)
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
            api: Self.serving()
        )
        #expect(manager.state == .finished)

        manager.reset()

        #expect(manager.state == .idle)
    }

    // MARK: - Helpers

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AIAction.self, AgendaEvent.self, AgendaTask.self, Client.self, FieldOption.self,
            RecentClient.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private static func store(
        tenant: StoredValue<String>,
        cursor: StoredValue<String> = .inMemory()
    ) -> LocalStore {
        LocalStore(tenantID: tenant, clientCursor: cursor)
    }

    /// Every startup route answered: the vocabulary, a client pass in two
    /// pages, the store's ids, and the recent clients — an empty list, inline
    /// until a fixture copied from the BFF replaces it.
    private nonisolated static func serving() -> APIClient {
        client { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("client/recent") {
                return (response(request, statusCode: 200), Data(#"{"items":[]}"#.utf8))
            }
            let name = switch true {
            case url.contains("client/filter"): "client_filter_ids"
            case url.contains("after=cursor-page-2"): "client_sync_page2"
            case url.contains("client/sync"): "client_sync_page1"
            default: "enums"
            }
            return (response(request, statusCode: 200), try Fixture.data(name))
        }
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

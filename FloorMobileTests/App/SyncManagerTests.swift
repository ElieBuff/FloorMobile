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

    /// In-memory marker standing in for the stored tenant. `@unchecked
    /// Sendable` is safe here: the suite is MainActor-confined.
    private final class Marker: @unchecked Sendable {
        var value: String?
        init(_ value: String?) { self.value = value }
    }

    @Test("A successful startup sync stores the vocabulary and opens the app")
    func finishesAndPersists() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(tenantGuard: Self.guard(Marker("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.client(statusCode: 200, body: try Fixture.data("enums"))
        )

        #expect(manager.state == .finished)
        let options = try ModelContext(container).fetch(FetchDescriptor<FieldOption>())
        let valueCount = try Fixture.enumsValueCount()
        #expect(options.count == valueCount)
    }

    @Test("A failure with nothing in store stops on the loading screen")
    func coldFailureBlocks() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(tenantGuard: Self.guard(Marker("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.client(statusCode: 500, body: Data())
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
        let manager = SyncManager(tenantGuard: Self.guard(Marker("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.client(statusCode: 500, body: Data())
        )

        // Offline in the shop: the advisor keeps what the last sync brought.
        #expect(manager.state == .finished)
        let values = try ModelContext(container).fetch(FetchDescriptor<FieldOption>()).map(\.value)
        #expect(values == ["CACHED"])
    }

    // This one aborted the whole process while the wipe still went through
    // `container.deleteAllData()`: the sync that follows writes via contexts
    // the services built at launch, which that call invalidates. It passes
    // now that `TenantGuard.erase` deletes rows instead — keep it.
    @Test("A tenant change wipes the store before anything is shown")
    func tenantChangeWipesFirst() async throws {
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            FieldOption(entityName: "task", field: "reason", value: "OTHER_TENANT", rank: 0)
        )
        try container.mainContext.save()
        let marker = Marker("org-1")
        let manager = SyncManager(tenantGuard: Self.guard(marker))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-2",
            services: AppServices(container: container),
            api: Self.client(statusCode: 200, body: try Fixture.data("enums"))
        )

        // The previous tenant's rows are gone, replaced by the new sync only.
        let values = try ModelContext(container).fetch(FetchDescriptor<FieldOption>()).map(\.value)
        #expect(!values.contains("OTHER_TENANT"))
        #expect(marker.value == "org-2")
    }

    /// A sign-out leaves the manager `.finished`, which would send the next
    /// sign-in straight into the app on a store `TenantGuard` just emptied.
    @Test("Resetting sends the next sign-in back through the sync")
    func resetReturnsToIdle() async throws {
        let container = try Self.inMemoryContainer()
        let manager = SyncManager(tenantGuard: Self.guard(Marker("org-1")))

        await manager.synchronize(
            context: container.mainContext,
            tenantID: "org-1",
            services: AppServices(container: container),
            api: Self.client(statusCode: 200, body: try Fixture.data("enums"))
        )
        #expect(manager.state == .finished)

        manager.reset()

        #expect(manager.state == .idle)
    }

    // MARK: - Helpers

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AIAction.self, AgendaEvent.self, AgendaTask.self, FieldOption.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private static func `guard`(_ marker: Marker) -> TenantGuard {
        TenantGuard(
            lastTenantID: { marker.value },
            setLastTenantID: { marker.value = $0 }
        )
    }

    private nonisolated static func client(statusCode: Int, body: Data) -> APIClient {
        APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            tokens: TokenProviding(
                validToken: { "valid-token" },
                refreshedToken: { "refreshed-token" }
            ),
            session: MockURLProtocol.session { request in
                let response = HTTPURLResponse(
                    url: request.url ?? URL(string: "https://invalid")!,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, body)
            }
        )
    }
}

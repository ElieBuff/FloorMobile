//
//  SetupServiceTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import FloorMobile

@Suite("Setup service")
@MainActor
struct SetupServiceTests {

    // MARK: - Vocabulary

    @Test("Fetches the setup and persists one row per allowed value")
    func synchronizePersistsVocabulary() async throws {
        let requestedPath = Mutex<String?>(nil)
        let client = Self.makeClient { request in
            requestedPath.withLock { $0 = request.url?.path() }
            return (Self.response(request, statusCode: 200), try Fixture.data("setup"))
        }
        let container = try Self.inMemoryContainer()

        try await SetupService(modelContainer: container).synchronize(using: client, localStore: Self.localStore())

        #expect(requestedPath.withLock { $0 }?.hasSuffix("setup") == true)
        let context = ModelContext(container)
        let reasons = try context.fetch(EnumValue.descriptor(for: .taskReason))
        #expect(reasons.count == 6)
        #expect(reasons.first?.value == "BIRTHDAY")

        // A second field on the same entity is stored beside the first, not
        // instead of it — `event` carries `reason`, `meetingType` and `status`.
        let types = try context.fetch(EnumValue.descriptor(for: .eventMeetingType))
        #expect(types.map(\.value) == ["IN_PERSON", "VIDEO_CALL"])

        // The two status vocabularies are distinct lists, kept apart by entity.
        let taskStatuses = try context.fetch(EnumValue.descriptor(for: .taskStatus))
        #expect(taskStatuses.map(\.value) == ["TO_DO", "COMPLETED", "CANCELED"])
        let eventStatuses = try context.fetch(EnumValue.descriptor(for: .eventStatus))
        #expect(eventStatuses.map(\.value) == ["PLANNED", "CONFIRMED", "COMPLETED", "CANCELLED"])
    }

    @Test("A value the server no longer allows disappears locally")
    func synchronizeDropsRetiredValues() async throws {
        let client = Self.serving("setup")
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            EnumValue(entityName: "task", field: "reason", value: "RETIRED", rank: 99)
        )
        try container.mainContext.save()

        try await SetupService(modelContainer: container).synchronize(using: client, localStore: Self.localStore())

        let values = try ModelContext(container)
            .fetch(FetchDescriptor<EnumValue>())
            .map(\.value)
        #expect(!values.contains("RETIRED"))
        #expect(values.count == (try Fixture.enumsValueCount()))
    }

    @Test("Syncing the same setup twice leaves no duplicates")
    func synchronizeTwiceIsIdempotent() async throws {
        let client = Self.serving("setup")
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client, localStore: Self.localStore())
        try await service.synchronize(using: client, localStore: Self.localStore())

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<EnumValue>()) == (try Fixture.enumsValueCount()))
        #expect(try context.fetchCount(FetchDescriptor<ClientFilter>()) == 2)
    }

    @Test("An unchanged setup is not written to the store")
    func synchronizeSkipsIdenticalPayload() async throws {
        let client = Self.serving("setup")
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client, localStore: Self.localStore())
        let before = try Self.identities(in: container)

        try await service.synchronize(using: client, localStore: Self.localStore())

        // Row identities survive only if the rows were left alone: the rewrite
        // path deletes and re-inserts, which mints new ones. This is what keeps
        // the launch from rewriting the whole configuration for nothing.
        #expect(try Self.identities(in: container) == before)
    }

    @Test("A vocabulary the server reordered is rewritten")
    func synchronizeRewritesOnReorder() async throws {
        let payloads = Mutex<[Data]>([
            try Self.payload(taskReasons: ["BIRTHDAY", "FOLLOW_UP"]),
            try Self.payload(taskReasons: ["FOLLOW_UP", "BIRTHDAY"]),
        ])
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), payloads.withLock { $0.removeFirst() })
        }
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client, localStore: Self.localStore())
        try await service.synchronize(using: client, localStore: Self.localStore())

        // Same two values, listed the other way round: `rank` is what the
        // pickers order by, so an identical *set* is still a real change.
        let reasons = try ModelContext(container).fetch(EnumValue.descriptor(for: .taskReason))
        #expect(reasons.map(\.value) == ["FOLLOW_UP", "BIRTHDAY"])
    }

    @Test("A server error surfaces and leaves the stored configuration in place")
    func synchronizePropagatesErrorAndKeepsData() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            EnumValue(entityName: "task", field: "reason", value: "KEPT", rank: 0)
        )
        container.mainContext.insert(
            ClientFilter(id: "kept", titleKey: "client.filter.kept", selectionRaw: "SINGLE", rank: 0, values: [])
        )
        try container.mainContext.save()

        await #expect(throws: AppError.self) {
            try await SetupService(modelContainer: container).synchronize(using: client, localStore: Self.localStore())
        }

        // Nothing is deleted before the new set is in hand: an old
        // configuration beats none.
        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<EnumValue>()).map(\.value) == ["KEPT"])
        #expect(try context.fetch(FetchDescriptor<ClientFilter>()).map(\.id) == ["kept"])
    }

    // MARK: - Client filters

    @Test("The tenant's filters are kept in the server's order, with their values")
    func synchronizePersistsFilters() async throws {
        let container = try Self.inMemoryContainer()

        try await SetupService(modelContainer: container).synchronize(using: Self.serving("setup"), localStore: Self.localStore())

        let filters = try ModelContext(container).fetch(
            FetchDescriptor<ClientFilter>(sortBy: [SortDescriptor(\.rank)])
        )
        #expect(filters.map(\.titleKey) == ["client.filter.created", "client.filter.lastPurchase"])
        #expect(filters.map(\.rank) == [0, 1])
        let created = try #require(filters.first)
        #expect(created.id == "01M5CJ75QEKQR98JVNHCZ675TN")
        #expect(created.selectionRaw == "SINGLE")
        #expect(created.values.map(\.labelKey) == [
            "client.filter.value.last3Months", "client.filter.value.last6Months",
            "client.filter.value.last12Months", "client.filter.value.since",
        ])
        // The value that takes a date, read back from the store.
        let since = try #require(created.values.last)
        #expect(since.ref == "01M5CJ75QJBRSDT2XAJCX5YYC9")
        #expect(since.parameters == [ClientFilterValue.Parameter(name: "since", typeRaw: "date")])
    }

    @Test("A filter the server no longer offers disappears, a changed one is rewritten")
    func synchronizeReplacesChangedFilters() async throws {
        let payloads = Mutex<[Data]>([
            try Self.payload(filters: [("a", "client.filter.a"), ("b", "client.filter.b")]),
            try Self.payload(filters: [("b", "client.filter.b.renamed")]),
        ])
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), payloads.withLock { $0.removeFirst() })
        }
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client, localStore: Self.localStore())
        try await service.synchronize(using: client, localStore: Self.localStore())

        let filters = try ModelContext(container).fetch(FetchDescriptor<ClientFilter>())
        #expect(filters.map(\.id) == ["b"])
        #expect(filters.first?.titleKey == "client.filter.b.renamed")
        #expect(filters.first?.rank == 0)
    }

    @Test("As many filters as before, one of them changed: the change is written")
    func synchronizeRewritesASameSizeChange() async throws {
        let payloads = Mutex<[Data]>([
            try Self.payload(filters: [("a", "client.filter.a"), ("b", "client.filter.b")]),
            try Self.payload(filters: [("a", "client.filter.a"), ("b", "client.filter.b.renamed")]),
        ])
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), payloads.withLock { $0.removeFirst() })
        }
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client, localStore: Self.localStore())
        try await service.synchronize(using: client, localStore: Self.localStore())

        // Same count, so the comparison has to look inside each filter.
        let filters = try ModelContext(container).fetch(
            FetchDescriptor<ClientFilter>(sortBy: [SortDescriptor(\.rank)])
        )
        #expect(filters.map(\.titleKey) == ["client.filter.a", "client.filter.b.renamed"])
    }

    @Test("The same filters in another order: the new order is written")
    func synchronizeRewritesAReorder() async throws {
        let payloads = Mutex<[Data]>([
            try Self.payload(filters: [("a", "client.filter.a"), ("b", "client.filter.b")]),
            try Self.payload(filters: [("b", "client.filter.b"), ("a", "client.filter.a")]),
        ])
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), payloads.withLock { $0.removeFirst() })
        }
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client, localStore: Self.localStore())
        try await service.synchronize(using: client, localStore: Self.localStore())

        let filters = try ModelContext(container).fetch(
            FetchDescriptor<ClientFilter>(sortBy: [SortDescriptor(\.rank)])
        )
        #expect(filters.map(\.id) == ["b", "a"])
        #expect(filters.map(\.rank) == [0, 1])
    }

    // MARK: - Sales associate

    @Test("The associate's language is kept, raw, beside the store")
    func synchronizeKeepsTheLanguage() async throws {
        let localStore = Self.localStore()

        try await SetupService(modelContainer: try Self.inMemoryContainer())
            .synchronize(using: Self.serving("setup"), localStore: localStore)

        #expect(localStore.preferredLanguage.get() == "Fr")
    }

    @Test("An associate with no language any more clears the kept one")
    func synchronizeClearsAMissingLanguage() async throws {
        let localStore = Self.localStore(language: "En")
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Self.payload(language: nil))
        }

        try await SetupService(modelContainer: try Self.inMemoryContainer())
            .synchronize(using: client, localStore: localStore)

        #expect(localStore.preferredLanguage.get() == nil)
    }

    // MARK: - Helpers

    /// A `LocalStore` held in memory: the tests never touch the device's
    /// `UserDefaults`.
    private nonisolated static func localStore(language: String? = nil) -> LocalStore {
        LocalStore(tenantID: .inMemory(), clientCursor: .inMemory(), preferredLanguage: .inMemory(language))
    }

    /// The store's row identities, which change if and only if the rows were
    /// deleted and re-inserted.
    private static func identities(in container: ModelContainer) throws -> Set<PersistentIdentifier> {
        let context = ModelContext(container)
        let values = try context.fetch(FetchDescriptor<EnumValue>()).map(\.persistentModelID)
        let filters = try context.fetch(FetchDescriptor<ClientFilter>()).map(\.persistentModelID)
        return Set(values + filters)
    }

    /// A minimal `GET setup` body: one vocabulary field in the given order,
    /// the given filters, each with no value, and the associate's language.
    private nonisolated static func payload(
        taskReasons: [String] = ["FOLLOW_UP"],
        filters: [(id: String, titleKey: String)] = [],
        language: String? = "Fr"
    ) throws -> Data {
        let body: [String: Any] = [
            "enums": ["task": ["reason": taskReasons]],
            "clients": [
                "filters": filters.map {
                    ["id": $0.id, "titleKey": $0.titleKey, "selection": "SINGLE", "values": [Any]()] as [String: Any]
                },
            ],
            "salesAssociate": ["preferredLanguage": language as Any? ?? NSNull()],
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: EnumValue.self, ClientFilter.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Every request answered with the same fixture.
    private nonisolated static func serving(_ fixture: String) -> APIClient {
        makeClient { request in
            (response(request, statusCode: 200), try Fixture.data(fixture))
        }
    }

    private nonisolated static func makeClient(
        handler: @escaping MockURLProtocol.Handler
    ) -> APIClient {
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

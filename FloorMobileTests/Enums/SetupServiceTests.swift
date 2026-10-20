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

        try await SetupService(modelContainer: container).synchronize(using: client)

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

        try await SetupService(modelContainer: container).synchronize(using: client)

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

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<EnumValue>()) == (try Fixture.enumsValueCount()))
        #expect(try context.fetchCount(FetchDescriptor<ClientFilter>()) == 2)
    }

    @Test("An unchanged setup is not written to the store")
    func synchronizeSkipsIdenticalPayload() async throws {
        let client = Self.serving("setup")
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client)
        let before = try Self.identities(in: container)

        try await service.synchronize(using: client)

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

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

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
            try await SetupService(modelContainer: container).synchronize(using: client)
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

        try await SetupService(modelContainer: container).synchronize(using: Self.serving("setup"))

        let filters = try ModelContext(container).fetch(
            FetchDescriptor<ClientFilter>(sortBy: [SortDescriptor(\.rank)])
        )
        #expect(filters.map(\.titleKey) == ["client.filter.created", "client.filter.lastPurchase"])
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

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        let filters = try ModelContext(container).fetch(FetchDescriptor<ClientFilter>())
        #expect(filters.map(\.id) == ["b"])
        #expect(filters.first?.titleKey == "client.filter.b.renamed")
        #expect(filters.first?.rank == 0)
    }

    // MARK: - Helpers

    /// The store's row identities, which change if and only if the rows were
    /// deleted and re-inserted.
    private static func identities(in container: ModelContainer) throws -> Set<PersistentIdentifier> {
        let context = ModelContext(container)
        let values = try context.fetch(FetchDescriptor<EnumValue>()).map(\.persistentModelID)
        let filters = try context.fetch(FetchDescriptor<ClientFilter>()).map(\.persistentModelID)
        return Set(values + filters)
    }

    /// A minimal `GET setup` body: one vocabulary field in the given order,
    /// and the given filters, each with no value.
    private nonisolated static func payload(
        taskReasons: [String] = ["FOLLOW_UP"],
        filters: [(id: String, titleKey: String)] = []
    ) throws -> Data {
        let body: [String: Any] = [
            "enums": ["task": ["reason": taskReasons]],
            "clients": [
                "filters": filters.map {
                    ["id": $0.id, "titleKey": $0.titleKey, "selection": "SINGLE", "values": [Any]()] as [String: Any]
                },
            ],
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

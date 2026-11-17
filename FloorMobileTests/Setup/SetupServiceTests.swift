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
        #expect(try context.fetchCount(FetchDescriptor<ClientSort>()) == 6)
        #expect(try context.fetchCount(FetchDescriptor<ClientSegment>()) == 4)
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
        // pickers order by, so the new order is the one they show.
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

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        let filters = try ModelContext(container).fetch(FetchDescriptor<ClientFilter>())
        #expect(filters.map(\.id) == ["b"])
        #expect(filters.first?.titleKey == "client.filter.b.renamed")
        #expect(filters.first?.rank == 0)
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

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        let filters = try ModelContext(container).fetch(
            FetchDescriptor<ClientFilter>(sortBy: [SortDescriptor(\.rank)])
        )
        #expect(filters.map(\.id) == ["b", "a"])
        #expect(filters.map(\.rank) == [0, 1])
    }

    // MARK: - Sales associate

    @Test("The real setup hands back the associate signed in and their store")
    func synchronizeHandsBackTheAssociate() async throws {
        let signedIn = try #require(
            try await SetupService(modelContainer: try Self.inMemoryContainer())
                .synchronize(using: Self.serving("setup"))
        )

        #expect(signedIn.associate == SalesAssociateSnapshot(
            id: "01KTRSFERMNXK5FGSQW11M1478", firstName: "Elie", lastName: "Buff", preferredLanguage: nil
        ))
        #expect(signedIn.store == StoreSnapshot(
            id: "09270e8c-d9ff-4c29-ba93-330212bda2ef", name: "Shop location", storeCode: "90917634296"
        ))
    }

    @Test("The associate's language comes with them, raw")
    func synchronizeHandsBackTheLanguage() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Self.payload(language: "Fr"))
        }

        let signedIn = try await SetupService(modelContainer: try Self.inMemoryContainer())
            .synchronize(using: client)

        #expect(signedIn?.associate.preferredLanguage == "Fr")
        #expect(signedIn?.store == nil)
    }

    // MARK: - Client sorts

    @Test("The tenant's sorts are kept in the server's positions, one by default")
    func synchronizePersistsSorts() async throws {
        let container = try Self.inMemoryContainer()

        try await SetupService(modelContainer: container)
            .synchronize(using: Self.serving("setup"))

        let sorts = try ModelContext(container).fetch(FetchDescriptor<ClientSort>(sortBy: [SortDescriptor(\.rank)]))
        #expect(sorts.map(\.value) == ["name", "lastPurchase", "spent12M", "spentLifetime", "createdDate", "contactedByMe"])
        #expect(sorts.map(\.rank) == Array(0..<6))
        #expect(sorts.filter(\.isDefault).map(\.value) == ["name"])
        #expect(sorts.first?.directionRaw == "asc")
        #expect(sorts.first?.labelKey == "client.sort.name")
    }

    @Test("Sorts the server lists out of order are kept by position")
    func synchronizeOrdersSortsByPosition() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Self.payload(sorts: [("b", 1, false), ("a", 0, true)]))
        }
        let container = try Self.inMemoryContainer()

        try await SetupService(modelContainer: container).synchronize(using: client)

        let sorts = try ModelContext(container).fetch(FetchDescriptor<ClientSort>(sortBy: [SortDescriptor(\.rank)]))
        #expect(sorts.map(\.value) == ["a", "b"])
    }

    @Test("A sort the server no longer offers disappears")
    func synchronizeDropsARetiredSort() async throws {
        let payloads = Mutex<[Data]>([
            try Self.payload(sorts: [("a", 0, true), ("b", 1, false)]),
            try Self.payload(sorts: [("a", 0, true)]),
        ])
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), payloads.withLock { $0.removeFirst() })
        }
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        #expect(try ModelContext(container).fetch(FetchDescriptor<ClientSort>()).map(\.value) == ["a"])
    }

    // MARK: - Client segments

    @Test("The brand's segments are kept in its order, with their colours")
    func synchronizePersistsSegments() async throws {
        let container = try Self.inMemoryContainer()

        try await SetupService(modelContainer: container).synchronize(using: Self.serving("setup"))

        let segments = try ModelContext(container).fetch(
            FetchDescriptor<ClientSegment>(sortBy: [SortDescriptor(\.rank)])
        )
        #expect(segments.map(\.code) == ["One Timer", "Connoisseur", "VIP", "VIC"])
        #expect(segments.map(\.rank) == Array(0..<4))
        let vic = try #require(segments.last)
        #expect(vic.backgroundColorHex == "#14545F")
        #expect(vic.textColorHex == "#ffffff")
    }

    @Test("A segment the server no longer lists disappears, a new colour lands")
    func synchronizeReplacesChangedSegments() async throws {
        let payloads = Mutex<[Data]>([
            try Self.payload(segments: [("VIC", "#14545F"), ("VIP", "#1454603D")]),
            try Self.payload(segments: [("VIC", "#000000")]),
        ])
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), payloads.withLock { $0.removeFirst() })
        }
        let container = try Self.inMemoryContainer()
        let service = SetupService(modelContainer: container)

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        let segments = try ModelContext(container).fetch(FetchDescriptor<ClientSegment>())
        #expect(segments.map(\.code) == ["VIC"])
        #expect(segments.first?.backgroundColorHex == "#000000")
    }

    @Test("A setup without an associate does not fail, and hands back none")
    func synchronizeWithoutAnAssociate() async throws {
        // The server sends null only if the record went between the token's check and the read.
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Self.payload(associate: false))
        }

        let signedIn = try await SetupService(modelContainer: try Self.inMemoryContainer())
            .synchronize(using: client)

        #expect(signedIn == nil)
    }

    // MARK: - Helpers

    /// A minimal `GET setup` body: one vocabulary field in the given order,
    /// the given filters, each with no value, the given sorts, the given
    /// segments, each with its fill and a white text, and the associate of
    /// the real fixture with the given language, without a store — or `null`
    /// for them.
    private nonisolated static func payload(
        taskReasons: [String] = ["FOLLOW_UP"],
        filters: [(id: String, titleKey: String)] = [],
        sorts: [(value: String, position: Int, isDefault: Bool)] = [],
        segments: [(code: String, backgroundColor: String)] = [],
        language: String? = "Fr",
        associate: Bool = true
    ) throws -> Data {
        let salesAssociate: Any = associate
            ? [
                "id": "01KTRSFERMNXK5FGSQW11M1478", "externalId": "378970372512460673",
                "firstName": "Elie", "lastName": "Buff", "preferredLanguage": language as Any? ?? NSNull(),
            ] as [String: Any]
            : NSNull()
        let body: [String: Any] = [
            "enums": ["task": ["reason": taskReasons]],
            "clientConfiguration": [
                "filters": filters.map {
                    ["id": $0.id, "titleKey": $0.titleKey, "selection": "SINGLE", "values": [Any]()] as [String: Any]
                },
                "sorts": sorts.map {
                    [
                        "value": $0.value, "labelKey": "client.sort.\($0.value)", "direction": "desc",
                        "isDefault": $0.isDefault, "position": $0.position,
                    ] as [String: Any]
                },
                "segments": segments.map {
                    [
                        "code": $0.code,
                        "style": ["backgroundColor": $0.backgroundColor, "textColor": "#FFFFFF"],
                    ] as [String: Any]
                },
            ],
            "salesAssociate": salesAssociate,
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: EnumValue.self, ClientFilter.self, ClientSegment.self, ClientSort.self,
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

//
//  EnumsServiceTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import FloorMobile

@Suite("Enums service")
@MainActor
struct EnumsServiceTests {

    @Test("Fetches the vocabulary and persists one row per allowed value")
    func synchronizePersistsVocabulary() async throws {
        let requestedPath = Mutex<String?>(nil)
        let client = Self.makeClient { request in
            requestedPath.withLock { $0 = request.url?.path() }
            return (Self.response(request, statusCode: 200), try Fixture.data("enums"))
        }
        let container = try Self.inMemoryContainer()

        try await EnumsService(modelContainer: container).synchronize(using: client)

        #expect(requestedPath.withLock { $0 }?.hasSuffix("enums") == true)
        let context = ModelContext(container)
        let reasons = try context.fetch(FieldOption.descriptor(for: .taskReason))
        #expect(reasons.count == 6)
        #expect(reasons.first?.value == "BIRTHDAY")

        // A second field on the same entity is stored beside the first, not
        // instead of it — `event` carries `reason`, `type` and `status`.
        let types = try context.fetch(FieldOption.descriptor(for: .eventMeetingType))
        #expect(types.map(\.value) == ["IN_PERSON", "VIDEO_CALL"])

        // The two status vocabularies are distinct lists, kept apart by entity.
        let taskStatuses = try context.fetch(FieldOption.descriptor(for: .taskStatus))
        #expect(taskStatuses.map(\.value) == ["TO_DO", "COMPLETED", "CANCELED"])
        let eventStatuses = try context.fetch(FieldOption.descriptor(for: .eventStatus))
        #expect(eventStatuses.map(\.value) == ["PLANNED", "CONFIRMED", "COMPLETED", "CANCELLED"])
    }

    @Test("A value the server no longer allows disappears locally")
    func synchronizeDropsRetiredValues() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Fixture.data("enums"))
        }
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            FieldOption(entityName: "task", field: "reason", value: "RETIRED", rank: 99)
        )
        try container.mainContext.save()

        try await EnumsService(modelContainer: container).synchronize(using: client)

        let values = try ModelContext(container)
            .fetch(FetchDescriptor<FieldOption>())
            .map(\.value)
        #expect(!values.contains("RETIRED"))
        #expect(values.count == 21)
    }

    @Test("Syncing the same payload twice leaves no duplicates")
    func synchronizeTwiceIsIdempotent() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Fixture.data("enums"))
        }
        let container = try Self.inMemoryContainer()
        let service = EnumsService(modelContainer: container)

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        let options = try ModelContext(container).fetch(FetchDescriptor<FieldOption>())
        #expect(options.count == 21)
    }

    @Test("An unchanged payload is not written to the store")
    func synchronizeSkipsIdenticalPayload() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Fixture.data("enums"))
        }
        let container = try Self.inMemoryContainer()
        let service = EnumsService(modelContainer: container)

        try await service.synchronize(using: client)
        let before = try Self.identities(in: container)

        try await service.synchronize(using: client)

        // Row identities survive only if the rows were left alone: the rewrite
        // path deletes and re-inserts, which mints new ones. This is what keeps
        // the launch from rewriting the whole vocabulary for nothing.
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
        let service = EnumsService(modelContainer: container)

        try await service.synchronize(using: client)
        try await service.synchronize(using: client)

        // Same two values, listed the other way round: `rank` is what the
        // pickers order by, so an identical *set* is still a real change.
        let reasons = try ModelContext(container).fetch(FieldOption.descriptor(for: .taskReason))
        #expect(reasons.map(\.value) == ["FOLLOW_UP", "BIRTHDAY"])
    }

    @Test("A server error surfaces and leaves the stored vocabulary in place")
    func synchronizePropagatesErrorAndKeepsData() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }
        let container = try Self.inMemoryContainer()
        container.mainContext.insert(
            FieldOption(entityName: "task", field: "reason", value: "KEPT", rank: 0)
        )
        try container.mainContext.save()

        await #expect(throws: AppError.self) {
            try await EnumsService(modelContainer: container).synchronize(using: client)
        }

        // Nothing is deleted before the new set is in hand: an old vocabulary
        // beats no vocabulary.
        let values = try ModelContext(container)
            .fetch(FetchDescriptor<FieldOption>())
            .map(\.value)
        #expect(values == ["KEPT"])
    }

    // MARK: - Helpers

    /// The store's row identities, which change if and only if the rows were
    /// deleted and re-inserted.
    private static func identities(in container: ModelContainer) throws -> Set<PersistentIdentifier> {
        let options = try ModelContext(container).fetch(FetchDescriptor<FieldOption>())
        return Set(options.map(\.persistentModelID))
    }

    /// A minimal `GET enums` body carrying one field, in the given order.
    private nonisolated static func payload(taskReasons: [String]) throws -> Data {
        let payload: EnumsPayload = ["task": ["reason": taskReasons]]
        return try JSONEncoder().encode(payload)
    }

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: FieldOption.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
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

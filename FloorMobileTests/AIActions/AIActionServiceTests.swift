//
//  AIActionServiceTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import FloorMobile

@Suite("AIAction service")
@MainActor
struct AIActionServiceTests {

    @Test("Fetches the pending actions and persists them as models")
    func synchronizePersistsFetchedActions() async throws {
        let requestedPath = Mutex<String?>(nil)
        let client = Self.makeClient { request in
            requestedPath.withLock { $0 = request.url?.path() }
            return (Self.response(request, statusCode: 200), try Fixture.data("ai_actions_page1"))
        }
        let container = try Self.inMemoryContainer()
        // A local action the server no longer returns: must be swept.
        container.mainContext.insert(AIAction(id: "stale", agentKey: "a", type: "t", title: "gone",
                                reason: "r", statusRaw: "PENDING", createdAt: Date(timeIntervalSince1970: 0)))
        try container.mainContext.save()

        try await AIActionService(modelContainer: container).synchronizePending(using: client)

        // The sync hit the endpoint we expose, and the wire row became a model.
        #expect(requestedPath.withLock { $0 }?.hasSuffix("ai-action/pending") == true)
        let actions = try ModelContext(container).fetch(FetchDescriptor<AIAction>())
        #expect(actions.count == 1)
        #expect(!actions.contains { $0.id == "stale" })
        let action = try #require(actions.first)
        #expect(action.id == "01M1HSBTH7TPQV8EZQFKN1ES25")
        #expect(action.agentKey == "contact-radar")
        #expect(action.status == .pending)
        #expect(action.clientDisplayName == "Elie Buff")
    }

    @Test("A server error surfaces and leaves the store untouched")
    func synchronizePropagatesErrorAndSavesNothing() async throws {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }
        let container = try Self.inMemoryContainer()

        await #expect(throws: AppError.self) {
            try await AIActionService(modelContainer: container).synchronizePending(using: client)
        }

        let actions = try ModelContext(container).fetch(FetchDescriptor<AIAction>())
        #expect(actions.isEmpty)
    }

    // MARK: - Helpers

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AIAction.self,
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

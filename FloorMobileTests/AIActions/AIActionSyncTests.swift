//
//  AIActionSyncTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import FloorMobile

@Suite("AIAction sync")
@MainActor
struct AIActionSyncTests {

    @Test("Fetches the pending actions and persists them as models")
    func synchronizePersistsFetchedActions() async throws {
        let requestedPath = Mutex<String?>(nil)
        let client = Self.makeClient { request in
            requestedPath.withLock { $0 = request.url?.path() }
            return (Self.response(request, statusCode: 200), try Fixture.data("ai_actions_page1"))
        }
        let context = try Self.inMemoryContext()

        try await AIActionSync.synchronize(using: client, context: context)

        // The sync hit the endpoint we expose, and the wire row became a model.
        #expect(requestedPath.withLock { $0 }?.hasSuffix("ai-action/pending") == true)
        let actions = try context.fetch(FetchDescriptor<AIAction>())
        #expect(actions.count == 1)
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
        let context = try Self.inMemoryContext()

        await #expect(throws: AppError.self) {
            try await AIActionSync.synchronize(using: client, context: context)
        }

        let actions = try context.fetch(FetchDescriptor<AIAction>())
        #expect(actions.isEmpty)
    }

    // MARK: - Helpers

    private static func inMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AIAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
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

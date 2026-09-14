//
//  AgendaServiceTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Agenda service")
@MainActor
struct AgendaServiceTests {

    @Test("Pages through the cursor, persists every page, and prunes stale events")
    func synchronizeEventsPaginatesAndPrunes() async throws {
        let context = try Self.inMemoryContext()
        // A local event the server no longer returns: must be pruned.
        context.insert(AgendaEvent(
            id: "stale", statusRaw: "PLANNED", typeRaw: "APPOINTMENT", title: "gone",
            startDate: Date(timeIntervalSince1970: 0), duration: 30,
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
        ))
        try context.save()

        // Page 1 (hasMore, nextCursor "cursor-2") until the client asks for "after=cursor-2".
        let client = Self.makeClient { request in
            let url = request.url?.absoluteString ?? ""
            let name = url.contains("after=cursor-2") ? "event_agenda_page2" : "event_agenda_page1"
            return (Self.response(request, statusCode: 200), try Fixture.data(name))
        }

        try await AgendaService.synchronizeEvents(using: client, context: context)

        let events = try context.fetch(FetchDescriptor<AgendaEvent>())
        #expect(Set(events.map(\.id)) == [
            "01M2FQ54RZ39T1TDG4E8YJWCS0",
            "01M2FQ9RQ3YDYMKV8T58C5KBB1",
            "01M2FVFVTEVQW4QEKX2KPVMW64",
        ])
        // The stale local row is gone.
        #expect(!events.contains { $0.id == "stale" })
    }

    // MARK: - Helpers

    private static func inMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AgendaEvent.self,
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

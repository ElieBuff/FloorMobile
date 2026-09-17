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
        let container = try Self.inMemoryContainer()
        // A local event the server no longer returns: must be pruned.
        container.mainContext.insert(AgendaEvent(
            id: "stale", statusRaw: "PLANNED", reasonRaw: "APPOINTMENT", title: "gone",
            startDate: Date(timeIntervalSince1970: 0), duration: 30,
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
        ))
        try container.mainContext.save()

        // Page 1 (hasMore, nextCursor "cursor-2") until the client asks for "after=cursor-2".
        let client = Self.makeClient { request in
            let url = request.url?.absoluteString ?? ""
            let name = url.contains("after=cursor-2") ? "event_agenda_page2" : "event_agenda_page1"
            return (Self.response(request, statusCode: 200), try Fixture.data(name))
        }

        try await AgendaService(modelContainer: container).synchronizeEvents(using: client)

        let events = try ModelContext(container).fetch(FetchDescriptor<AgendaEvent>())
        #expect(Set(events.map(\.id)) == [
            "01M2FQ54RZ39T1TDG4E8YJWCS0",
            "01M2FQ9RQ3YDYMKV8T58C5KBB1",
            "01M2FVFVTEVQW4QEKX2KPVMW64",
        ])
        // The stale local row is gone.
        #expect(!events.contains { $0.id == "stale" })
    }

    @Test("Fetches the tasks and prunes stale ones")
    func synchronizeTasksPersistsAndPrunes() async throws {
        let container = try Self.inMemoryContainer()
        // A local task the server no longer returns: must be pruned.
        container.mainContext.insert(AgendaTask(
            id: "stale", statusRaw: "TODO", reasonRaw: "CALL", title: "gone",
            startDate: Date(timeIntervalSince1970: 0),
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
        ))
        try container.mainContext.save()

        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), try Fixture.data("task_agenda_page1"))
        }

        try await AgendaService(modelContainer: container).synchronizeTasks(using: client)

        let tasks = try ModelContext(container).fetch(FetchDescriptor<AgendaTask>())
        #expect(Set(tasks.map(\.id)) == ["01M2FVMQ0HZN3Y1JMCMYD4PS3M"])
        #expect(!tasks.contains { $0.id == "stale" })
    }

    // MARK: - Helpers

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AgendaEvent.self, AgendaTask.self,
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

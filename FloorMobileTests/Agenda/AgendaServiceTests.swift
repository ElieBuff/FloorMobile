//
//  AgendaServiceTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Synchronization
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
            id: "stale", statusRaw: "TO_DO", reasonRaw: "FOLLOW_UP", title: "gone",
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

    // MARK: - Writes

    @Test("A new task is POSTed, and what comes back is stored")
    func saveCreatesAndStoresTheResponse() async throws {
        let container = try Self.inMemoryContainer()
        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 201), try Fixture.data("task_created"))
        }

        var draft = TaskDraft(day: Date(timeIntervalSince1970: 0))
        draft.title = "Rappeler Mme Dupont"
        draft.reason = .birthday

        try await AgendaService(modelContainer: container).saveTask(draft, using: client)

        let request = try #require(captured.withLock { $0 })
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/task")

        // The server's own row, not the draft's: the id and the client only
        // exist in the response.
        let tasks = try ModelContext(container).fetch(FetchDescriptor<AgendaTask>())
        let saved = try #require(tasks.first)
        #expect(tasks.count == 1)
        #expect(saved.id == "01M344FT2ESBR0YZCYH6PXF97M")
        #expect(saved.title == "Rappeler Mme Dupont")
        #expect(saved.clientDisplayName == "Raphaël Van den Berg")
        #expect(saved.store?.name == "Shop location")
        // Stamped, so the next refresh can tell it apart from a stale row.
        #expect(!saved.syncToken.isEmpty)
    }

    @Test("An edited task is PUT on its own path, and replaces the local row")
    func saveUpdatesTheExistingRow() async throws {
        let container = try Self.inMemoryContainer()
        let epoch = Date(timeIntervalSince1970: 0)
        container.mainContext.insert(AgendaTask(
            id: "01M344FT2ESBR0YZCYH6PXF97M", statusRaw: "TO_DO", reasonRaw: "FOLLOW_UP",
            title: "before", startDate: epoch, createdAt: epoch, updatedAt: epoch
        ))
        try container.mainContext.save()

        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 200), try Fixture.data("task_created"))
        }

        var draft = TaskDraft(day: epoch)
        draft.id = "01M344FT2ESBR0YZCYH6PXF97M"
        draft.title = "Rappeler Mme Dupont"

        try await AgendaService(modelContainer: container).saveTask(draft, using: client)

        let request = try #require(captured.withLock { $0 })
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path() == "/task/01M344FT2ESBR0YZCYH6PXF97M")

        // Upserted on the unique id rather than duplicated.
        let tasks = try ModelContext(container).fetch(FetchDescriptor<AgendaTask>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Rappeler Mme Dupont")
    }

    @Test("A server error is propagated and nothing is stored")
    func saveFailurePersistsNothing() async throws {
        let container = try Self.inMemoryContainer()
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }

        var draft = TaskDraft(day: Date(timeIntervalSince1970: 0))
        draft.title = "Rappeler Mme Dupont"

        await #expect(throws: AppError.self) {
            try await AgendaService(modelContainer: container).saveTask(draft, using: client)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<AgendaTask>()).isEmpty)
    }

    @Test("Ticking a task PATCHes its status, and the stored row follows the response")
    func updateTaskStatusPatchesAndStores() async throws {
        let container = try Self.inMemoryContainer()
        let epoch = Date(timeIntervalSince1970: 0)
        // The local row still says TODO; the fixture is the task as the server
        // has it after the change.
        container.mainContext.insert(AgendaTask(
            id: "01M344FT2ESBR0YZCYH6PXF97M", statusRaw: "TO_DO", reasonRaw: "BIRTHDAY",
            title: "Rappeler Mme Dupont", startDate: epoch,
            createdAt: epoch, updatedAt: epoch
        ))
        try container.mainContext.save()

        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 200), try Fixture.data("task_done"))
        }

        try await AgendaService(modelContainer: container)
            .updateTaskStatus(id: "01M344FT2ESBR0YZCYH6PXF97M", to: .completed, using: client)

        let request = try #require(captured.withLock { $0 })
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path() == "/task/01M344FT2ESBR0YZCYH6PXF97M/status")
        // The route's schema is strict: the body has to be exactly this.
        let body = try #require(request.bodyData)
        #expect(String(data: body, encoding: .utf8) == #"{"status":"COMPLETED"}"#)

        let tasks = try ModelContext(container).fetch(FetchDescriptor<AgendaTask>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.statusRaw == "COMPLETED")
        #expect(tasks.first?.status == .completed)
    }

    @Test("A status that fails to save leaves the local row as it was")
    func updateTaskStatusFailureKeepsTheRow() async throws {
        let container = try Self.inMemoryContainer()
        let epoch = Date(timeIntervalSince1970: 0)
        container.mainContext.insert(AgendaTask(
            id: "t1", statusRaw: "TO_DO", reasonRaw: "BIRTHDAY", title: "Rappeler Mme Dupont",
            startDate: epoch, createdAt: epoch, updatedAt: epoch
        ))
        try container.mainContext.save()

        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }

        await #expect(throws: AppError.self) {
            try await AgendaService(modelContainer: container)
                .updateTaskStatus(id: "t1", to: .completed, using: client)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<AgendaTask>()).first?.statusRaw == "TO_DO")
    }

    @Test("A new appointment is POSTed, and what comes back is stored")
    func saveEventCreatesAndStoresTheResponse() async throws {
        let container = try Self.inMemoryContainer()
        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 201), try Fixture.data("event_created"))
        }

        var draft = EventDraft(day: Date(timeIntervalSince1970: 0))
        draft.title = "Essayage collection automne"
        draft.reason = .backInStock
        draft.duration = 45

        try await AgendaService(modelContainer: container).saveEvent(draft, using: client)

        let request = try #require(captured.withLock { $0 })
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/event")

        let events = try ModelContext(container).fetch(FetchDescriptor<AgendaEvent>())
        let saved = try #require(events.first)
        #expect(events.count == 1)
        #expect(saved.id == "01M344H8YBXQ7VQ6ZJ0P4KTR2C")
        #expect(saved.duration == 45)
        #expect(saved.meetingType == .inPerson)
        #expect(saved.clientDisplayName == "Raphaël Van den Berg")
        #expect(!saved.syncToken.isEmpty)
    }

    @Test("An edited appointment is PUT on its own path, and replaces the local row")
    func saveEventUpdatesTheExistingRow() async throws {
        let container = try Self.inMemoryContainer()
        let epoch = Date(timeIntervalSince1970: 0)
        container.mainContext.insert(AgendaEvent(
            id: "01M344H8YBXQ7VQ6ZJ0P4KTR2C", statusRaw: "PLANNED", reasonRaw: "FOLLOW_UP",
            title: "before", startDate: epoch, duration: 30,
            createdAt: epoch, updatedAt: epoch
        ))
        try container.mainContext.save()

        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 200), try Fixture.data("event_created"))
        }

        var draft = EventDraft(day: epoch)
        draft.id = "01M344H8YBXQ7VQ6ZJ0P4KTR2C"
        draft.title = "Essayage collection automne"

        try await AgendaService(modelContainer: container).saveEvent(draft, using: client)

        let request = try #require(captured.withLock { $0 })
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path() == "/event/01M344H8YBXQ7VQ6ZJ0P4KTR2C")

        let events = try ModelContext(container).fetch(FetchDescriptor<AgendaEvent>())
        #expect(events.count == 1)
        #expect(events.first?.title == "Essayage collection automne")
        #expect(events.first?.duration == 45)
    }

    @Test("A failed appointment save stores nothing")
    func saveEventFailurePersistsNothing() async throws {
        let container = try Self.inMemoryContainer()
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }

        var draft = EventDraft(day: Date(timeIntervalSince1970: 0))
        draft.title = "Essayage collection automne"

        await #expect(throws: AppError.self) {
            try await AgendaService(modelContainer: container).saveEvent(draft, using: client)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<AgendaEvent>()).isEmpty)
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

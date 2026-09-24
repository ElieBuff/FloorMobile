//
//  AgendaEndpointTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Agenda endpoints")
struct AgendaEndpointTests {

    private static func request() -> TaskRequest {
        TaskRequest(draft: TaskDraft(day: Date(timeIntervalSince1970: 0)))
    }

    @Test("Creating a task: a POST on the collection, with a body")
    func createTaskEndpoint() {
        let endpoint = Endpoint.createTask(Self.request())

        #expect(endpoint.path == "task")
        #expect(endpoint.method == .post)
        #expect(endpoint.query.isEmpty)
        #expect(endpoint.body != nil)
    }

    @Test("Updating a task: a PUT on the task's own path")
    func updateTaskEndpoint() {
        let endpoint = Endpoint.updateTask(id: "01M344FT2ESBR0YZCYH6PXF97M", body: Self.request())

        #expect(endpoint.path == "task/01M344FT2ESBR0YZCYH6PXF97M")
        #expect(endpoint.method == .put)
        #expect(endpoint.query.isEmpty)
        #expect(endpoint.body != nil)
    }

    @Test("Ticking a task: a PATCH on the task's status sub-resource")
    func updateTaskStatusEndpoint() throws {
        let endpoint = Endpoint.updateTaskStatus(
            id: "01M344FT2ESBR0YZCYH6PXF97M",
            status: TaskStatus.completed.rawValue
        )

        #expect(endpoint.path == "task/01M344FT2ESBR0YZCYH6PXF97M/status")
        #expect(endpoint.method == .patch)
        #expect(endpoint.query.isEmpty)
    }

    /// The route's schema is strict server-side: one spare key is a 400, not
    /// something quietly ignored.
    @Test("The status body carries the status and nothing else")
    func updateTaskStatusBodyIsJustTheStatus() throws {
        let body = try #require(
            Endpoint.updateTaskStatus(id: "t1", status: "COMPLETED").body as? [String: String]
        )

        #expect(body == ["status": "COMPLETED"])
    }

    @Test("Booking an appointment: a POST on the collection, with a body")
    func createEventEndpoint() {
        let endpoint = Endpoint.createEvent(EventRequest(draft: EventDraft(day: Date(timeIntervalSince1970: 0))))

        #expect(endpoint.path == "event")
        #expect(endpoint.method == .post)
        #expect(endpoint.query.isEmpty)
        #expect(endpoint.body != nil)
    }

    @Test("Updating an appointment: a PUT on the event's own path")
    func updateEventEndpoint() {
        let endpoint = Endpoint.updateEvent(
            id: "01M344H8YBXQ7VQ6ZJ0P4KTR2C",
            body: EventRequest(draft: EventDraft(day: Date(timeIntervalSince1970: 0)))
        )

        #expect(endpoint.path == "event/01M344H8YBXQ7VQ6ZJ0P4KTR2C")
        #expect(endpoint.method == .put)
        #expect(endpoint.query.isEmpty)
        #expect(endpoint.body != nil)
    }

    @Test("Reading stays a GET, and the cursor travels as a query item")
    func agendaReadsAreUnchanged() {
        #expect(Endpoint.tasks().method == .get)
        #expect(Endpoint.tasks().path == "task/agenda")
        #expect(Endpoint.tasks(after: "cursor-2").query == [URLQueryItem(name: "after", value: "cursor-2")])
        #expect(Endpoint.eventAgenda().path == "event/agenda")
    }
}

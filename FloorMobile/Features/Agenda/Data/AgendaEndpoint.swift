//
//  AgendaEndpoint.swift
//  FloorMobile
//

import Foundation

// MARK: - Agenda Endpoints

nonisolated extension Endpoint {
    /// The connected sales associate's event agenda — a fixed window around
    /// today (−1 month / +3 months) defined server-side, cursor-paginated.
    /// Pass the previous page's `nextCursor` as `after` to get the next page.
    static func eventAgenda(after cursor: String? = nil) -> Endpoint {
        Endpoint(
            path: "event/agenda",
            query: cursor.map { [URLQueryItem(name: "after", value: $0)] } ?? []
        )
    }

    /// The connected sales associate's tasks, cursor-paginated. Pass the
    /// previous page's `nextCursor` as `after` to get the next page.
    static func tasks(after cursor: String? = nil) -> Endpoint {
        Endpoint(
            path: "task/agenda",
            query: cursor.map { [URLQueryItem(name: "after", value: $0)] } ?? []
        )
    }

    /// Creates a task. The created task comes back in the same shape the agenda
    /// list serves, so one `TaskDTO` decodes both.
    static func createTask(_ body: TaskRequest) -> Endpoint {
        Endpoint(path: "task", method: .post, body: body)
    }

    /// Replaces a task: a `PUT` of the whole task, not a patch — whatever the
    /// body carries is what the task becomes.
    static func updateTask(id: String, body: TaskRequest) -> Endpoint {
        Endpoint(path: "task/\(id)", method: .put, body: body)
    }

    /// Moves a task to another status — what ticking a row does, as opposed to
    /// editing the task. A `PATCH` on the task's own `status` sub-resource, so
    /// nothing else about it is sent, and the updated task comes back.
    ///
    /// The body is a dictionary rather than a request type: one field, written
    /// in one place, and the route's schema is strict — a spare key is a
    /// rejected request. `TaskRequest` earns its type by mapping nine fields
    /// off a draft; there is nothing here to map.
    static func updateTaskStatus(id: String, status: String) -> Endpoint {
        Endpoint(
            path: "task/\(id)/status",
            method: .patch,
            body: ["status": status]
        )
    }

    /// Books an appointment. The created event comes back in the same shape the
    /// agenda serves, so one `EventDTO` decodes both.
    static func createEvent(_ body: EventRequest) -> Endpoint {
        Endpoint(path: "event", method: .post, body: body)
    }

    /// Replaces an appointment — a `PUT` of the whole event, not a patch.
    static func updateEvent(id: String, body: EventRequest) -> Endpoint {
        Endpoint(path: "event/\(id)", method: .put, body: body)
    }
}

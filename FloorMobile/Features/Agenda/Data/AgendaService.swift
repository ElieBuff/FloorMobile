//
//  AgendaService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// The Agenda feature's data service: reads and writes between the Floor API
/// and SwiftData. A `@ModelActor` so its writes run off the main actor on a
/// private, actor-owned context.
@ModelActor
actor AgendaService {

    /// Fetches the event agenda (server-defined window around today) and
    /// reconciles it into SwiftData: pages through the cursor, persisting each
    /// page as it arrives, then prunes the events the server no longer returns.
    func synchronizeEvents(using client: APIClient) async throws {
        try await modelContext.refresh(
            paginatedBy: { try await client.send(.eventAgenda(after: $0)) },
            make: AgendaEvent.init(dto:)
        )
    }

    /// Fetches the tasks and reconciles them into SwiftData: pages through the
    /// cursor, persisting each page as it arrives, then prunes the tasks the
    /// server no longer returns.
    func synchronizeTasks(using client: APIClient) async throws {
        try await modelContext.refresh(
            paginatedBy: { try await client.send(.tasks(after: $0)) },
            make: AgendaTask.init(dto:)
        )
    }

    /// Sends a composed task and stores what comes back.
    ///
    /// One method for both halves of the write: the draft's `id` is the whole
    /// difference between creating and replacing, and it is the draft — not the
    /// view — that knows which it is.
    func saveTask(_ draft: TaskDraft, using client: APIClient) async throws {
        let body = TaskRequest(draft: draft)
        let saved: TaskDTO
        if let id = draft.id {
            saved = try await client.send(.updateTask(id: id, body: body))
        } else {
            saved = try await client.send(.createTask(body))
        }
        try store(saved)
    }

    /// Moves a task to another status and stores what comes back.
    ///
    /// Separate from `saveTask(_:using:)` on purpose: this route replaces one
    /// field, where a save replaces the whole task. Ticking a row must not
    /// carry along whatever the form happened to hold.
    /// Typed, unlike the draft's `status`: a draft carries whatever the server
    /// sent, including values this build does not know, while a status the app
    /// *asserts* can only be one it understands.
    func updateTaskStatus(id: String, to status: TaskStatus, using client: APIClient) async throws {
        let saved: TaskDTO = try await client.send(
            .updateTaskStatus(id: id, status: status.rawValue)
        )
        try store(saved)
    }

    /// Sends a composed appointment and stores what comes back. The event
    /// half of `saveTask(_:using:)`, and the same rule: the draft's `id` is
    /// what separates booking from replacing.
    func saveEvent(_ draft: EventDraft, using client: APIClient) async throws {
        let body = EventRequest(draft: draft)
        let saved: EventDTO
        if let id = draft.id {
            saved = try await client.send(.updateEvent(id: id, body: body))
        } else {
            saved = try await client.send(.createEvent(body))
        }
        try store(saved)
    }

    /// The response is a whole task, so nothing needs re-fetching: it is
    /// upserted straight in and the agenda's `@Query` shows it.
    ///
    /// Stamped with a token of its own. A refresh finishing in the same breath
    /// could still sweep the row — it bears no token that refresh minted — but
    /// the server now has the task, so the next refresh brings it back.
    private func store(_ dto: TaskDTO) throws {
        try modelContext.upsert([dto]) { item in
            let task = AgendaTask(dto: item)
            task.syncToken = UUID().uuidString
            return task
        }
    }

    /// The event counterpart of `store(_ dto: TaskDTO)`, same reasoning.
    private func store(_ dto: EventDTO) throws {
        try modelContext.upsert([dto]) { item in
            let event = AgendaEvent(dto: item)
            event.syncToken = UUID().uuidString
            return event
        }
    }
}

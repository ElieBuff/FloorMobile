//
//  AgendaService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// The Agenda feature's data service: reads (and, later, mutations) between the
/// Floor API and SwiftData. A `@ModelActor` so its writes run off the main
/// actor on a private, actor-owned context.
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
}

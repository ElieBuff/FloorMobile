//
//  AgendaService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// The Agenda feature's data service: reads (and, later, mutations) between the
/// Floor API and SwiftData.
struct AgendaService {

    /// Fetches the event agenda (server-defined window around today) and
    /// reconciles it into SwiftData: pages through the cursor, persisting each
    /// page as it arrives, then prunes the events the server no longer returns.
    static func synchronizeEvents(
        using client: APIClient,
        context: ModelContext
    ) async throws {
        try await context.refresh(
            paginatedBy: { try await client.send(.eventAgenda(after: $0)) },
            make: AgendaEvent.init(dto:)
        )
    }
}

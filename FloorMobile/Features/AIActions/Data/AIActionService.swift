//
//  AIActionService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// The AI actions feature's data service: reads (and, later, lifecycle
/// mutations) between the Floor API and SwiftData. A `@ModelActor` so its
/// writes run off the main actor on a private, actor-owned context.
@ModelActor
actor AIActionService {

    /// Fetches the current AI actions and reconciles them into SwiftData:
    /// upserts the incoming set and prunes the rows the server no longer
    /// returns (resolved, expired, superseded).
    func synchronizePending(using client: APIClient) async throws {
        try await modelContext.refresh(
            from: { try await client.send(.getPendingActions()) },
            make: AIAction.init(dto:)
        )
    }
}

//
//  AIActionSync.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// Handles synchronization of AI actions from the API to SwiftData.
struct AIActionSync {

    /// Fetches the current AI actions and reconciles them into SwiftData:
    /// upserts the incoming set and prunes the rows the server no longer
    /// returns (resolved, expired, superseded).
    static func synchronize(
        using client: APIClient,
        context: ModelContext
    ) async throws {
        let dtos: [AIActionDTO] = try await client.send(.getPendingActions())
        try context.reconcile(
            incoming: dtos,
            incomingID: \.id,
            modelID: \AIAction.id,
            make: AIAction.init(dto:)
        )
    }
}

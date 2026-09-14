//
//  AIActionService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// The AI actions feature's data service: reads (and, later, lifecycle
/// mutations) between the Floor API and SwiftData.
struct AIActionService {

    /// Fetches the current AI actions and reconciles them into SwiftData:
    /// upserts the incoming set and prunes the rows the server no longer
    /// returns (resolved, expired, superseded).
    static func synchronizePending(
        using client: APIClient,
        context: ModelContext
    ) async throws {
        try await context.refresh(
            from: { try await client.send(.getPendingActions()) },
            make: AIAction.init(dto:)
        )
    }
}

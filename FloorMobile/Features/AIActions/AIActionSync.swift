//
//  AIActionSync.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// Handles synchronization of AI actions from the API to SwiftData.
struct AIActionSync {

    /// Fetches AI actions from the API and saves them to SwiftData.
    static func synchronize(
        using client: APIClient,
        context: ModelContext
    ) async throws {
        let dtos: [AIActionDTO] = try await client.send(.getPendingActions())
        for dto in dtos {
            context.insert(AIAction(dto: dto))
        }
        try context.save()
    }
}

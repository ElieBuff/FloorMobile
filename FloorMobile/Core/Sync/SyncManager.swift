//
//  SyncManager.swift
//  FloorMobile
//
//  Created by elie buff on 07/09/2026.
//

import Foundation
import SwiftData

/// Handles data synchronization at application startup.
///
/// The state is observed by the loading view to display progress and switch
/// to the main screen once the synchronization is complete.
@MainActor
@Observable
final class SyncManager {

    /// The different stages of the synchronization.
    enum State: Equatable {
        case idle
        case syncing
        case finished
        case failed(String)
    }

    private(set) var state: State = .idle

    /// Starts the data synchronization.
    ///
    /// - Parameter context: The SwiftData context in which to insert the data.
    func synchronize(context: ModelContext) async {
        state = .syncing

        do {
            // TODO: Replace with the real synchronization network call
            // (fetch remote data, then insert/update it in the `context`).
            try await performSync(context: context)
            state = .finished
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Synchronization implementation.
    ///
    /// For now this is a simulated delay, acting as a placeholder for the
    /// future data fetching and persistence logic.
    private func performSync(context: ModelContext) async throws {
        // Simulates the duration of a network call.
        try await Task.sleep(for: .seconds(2))
    }
}

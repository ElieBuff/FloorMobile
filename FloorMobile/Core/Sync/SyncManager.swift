//
//  SyncManager.swift
//  FloorMobile
//
//  Created by elie buff on 07/09/2026.
//

import Foundation
import SwiftData
import os

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

    /// Back to square one when the session ends. Without this the manager
    /// stays `.finished` across a sign-out, and the next sign-in walks
    /// straight into the app on a store `TenantGuard` has just emptied —
    /// no events, no tasks, and pickers falling back to their local lists.
    func reset() {
        state = .idle
    }

    private let tenantGuard: TenantGuard

    init(tenantGuard: TenantGuard = .live) {
        self.tenantGuard = tenantGuard
    }

    /// Starts the data synchronization.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context in which to insert the data.
    ///   - tenantID: The active tenant; a change from the last run wipes the
    ///     store before any data is shown (single-tenant isolation).
    ///   - services: The data services the startup payload runs through.
    ///   - api: The client those services fetch with.
    func synchronize(
        context: ModelContext,
        tenantID: String?,
        services: AppServices,
        api: APIClient
    ) async {
        state = .syncing

        do {
            try tenantGuard.enforce(currentTenantID: tenantID, context: context)
        } catch {
            // A failed wipe is an isolation breach, not a refresh hiccup:
            // never fall through to the cache below, it belongs to the tenant
            // this wipe failed to erase.
            AppLog.ui.error(
                "Tenant wipe failed: \(error.localizedDescription, privacy: .public)"
            )
            state = .failed(error.localizedDescription)
            return
        }

        do {
            try await performSync(services: services, api: api)
            state = .finished
        } catch {
            // Data already on the device beats a locked launch: a refresh that
            // fails on a store an earlier run filled lets the app open on what
            // it has — the shop's wifi is not always there. Only a cold start
            // with nothing to show stops on this screen.
            if hasUsableCache(in: context) {
                AppLog.ui.error(
                    "Startup sync failed, opening on cached data: \(error.localizedDescription, privacy: .public)"
                )
                state = .finished
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// What the app needs before it can show anything.
    ///
    /// One entry today — the server's field vocabulary, which every picker
    /// reads. Feature data (events, tasks, AI actions) is deliberately absent:
    /// each screen loads its own on appear and on pull-to-refresh, and must
    /// not hold the launch back. Several entries here fan out with `async
    /// let`, the way `HomeView` does.
    private func performSync(services: AppServices, api: APIClient) async throws {
        try await services.enums.synchronize(using: api)
    }

    /// Whether an earlier run left something usable behind. The vocabulary is
    /// all the launch fetches today, so it is all there is to look at; extend
    /// this alongside `performSync`.
    private func hasUsableCache(in context: ModelContext) -> Bool {
        let count = try? context.fetchCount(FetchDescriptor<FieldOption>())
        return (count ?? 0) > 0
    }
}

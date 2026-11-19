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
    /// straight into the app on a store `LocalStore` has just emptied —
    /// no events, no tasks, and pickers falling back to their local lists.
    func reset() {
        state = .idle
    }

    private let localStore: LocalStore

    init(localStore: LocalStore = .live) {
        self.localStore = localStore
    }

    /// Starts the data synchronization.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context in which to insert the data.
    ///   - tenantID: The active tenant; a change from the last run wipes the
    ///     store before any data is shown (single-tenant isolation).
    ///   - services: The data services the startup payload runs through.
    ///   - api: The client those services fetch with.
    ///   - keepSignedInAssociate: Given the associate signed in and their
    ///     store once `GET setup` is in — `AppSession.keep` in the app. Not
    ///     called when it fails: the session keeps the ones it had.
    func synchronize(
        context: ModelContext,
        tenantID: String?,
        services: AppServices,
        api: APIClient,
        keepSignedInAssociate: (SalesAssociateSnapshot?, StoreSnapshot?) -> Void
    ) async {
        state = .syncing

        do {
            try localStore.enforceTenant(tenantID, context: context)
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
            try await performSync(services: services, api: api, keepSignedInAssociate: keepSignedInAssociate)
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

    /// What the launch brings up to date: the app's configuration
    /// (`GET setup`) — the field vocabulary, which every picker reads, the
    /// tenant's "My Clients" filters and sorts, the brand's segments, and the
    /// associate signed in with their store, handed on as soon as they are in.
    ///
    /// Nothing else holds the launch back. The clients are asked of the
    /// server when their list opens and kept nowhere (decision of 19/11);
    /// feature data that changes by the hour (events, tasks, AI actions) is
    /// loaded by Home on appear and on pull-to-refresh.
    private func performSync(
        services: AppServices,
        api: APIClient,
        keepSignedInAssociate: (SalesAssociateSnapshot?, StoreSnapshot?) -> Void
    ) async throws {
        let signedIn = try await services.setup.synchronize(using: api)
        keepSignedInAssociate(signedIn?.associate, signedIn?.store)
    }

    /// Whether an earlier run left something usable behind — one entry per
    /// line of `performSync` that can fail it. The configuration counts by
    /// its vocabulary alone: a tenant may have no filter, never an empty
    /// vocabulary.
    private func hasUsableCache(in context: ModelContext) -> Bool {
        let vocabulary = (try? context.fetchCount(FetchDescriptor<EnumValue>())) ?? 0
        return vocabulary > 0
    }
}

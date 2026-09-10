//
//  SessionSync.swift
//  FloorMobile
//

import Foundation
import SwiftData
import os

/// Runs a data-sync operation under the app-wide session policy.
///
/// On an expired session (`AppError.authentication`) it purges all local data
/// and signs out — `RootView` then routes to login. Any other failure is
/// logged and swallowed, leaving already-cached data on screen. Every feature
/// sync funnels through here so the policy lives in exactly one place.
enum SessionSync {
    @MainActor
    static func run(
        label: String,
        session: AppSession,
        context: ModelContext,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
        } catch AppError.authentication {
            context.container.deleteAllData()
            await session.signOut()
        } catch {
            AppLog.ui.error("\(label, privacy: .public) sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

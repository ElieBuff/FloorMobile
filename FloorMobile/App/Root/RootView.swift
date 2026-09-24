//
//  RootView.swift
//  FloorMobile
//
//  Created by elie buff on 07/09/2026.
//

import SwiftUI
import SwiftData

/// Root switchboard: session first (login), then data (sync), then the app.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(SessionExpiry.self) private var expiry
    @State private var syncManager = SyncManager()

    var body: some View {
        content
            // The one place an expired session is acted on. `APIClient` raises
            // it from whichever call noticed; nothing in between has to pass it
            // along, and no screen has to remember to ask.
            .onChange(of: expiry.hasExpired) { _, hasExpired in
                guard hasExpired else { return }
                Task { await endSession() }
            }
            // However the session ends — expiry here, a sign-out elsewhere —
            // the next sign-in has to sync again rather than walk into the app
            // on the store that was just wiped.
            .onChange(of: session.state) { _, newValue in
                guard case .authenticated = newValue else {
                    syncManager.reset()
                    return
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .loading:
            LoadingView(message: String(localized: "Loading…"))
        case .unauthenticated, .authenticating, .failed:
            LoginView()
        case .authenticated:
            syncedContent
        }
    }

    /// Row by row, not `deleteAllData()`: the container reset would invalidate
    /// the long-lived contexts the services hold, and a re-login without an app
    /// restart writes through those very contexts (see `TenantGuard.erase`).
    private func endSession() async {
        try? TenantGuard.erase(in: modelContext)
        await session.signOut()
        expiry.hasExpired = false
    }

    /// The startup sync, shown once the user is signed in.
    @ViewBuilder
    private var syncedContent: some View {
        switch syncManager.state {
        case .finished:
            MainTabView()
        case .failed(let message):
            LoadingView(message: message) {
                Task { await startSync() }
            }
        case .idle, .syncing:
            LoadingView(message: String(localized: "Synchronizing data…"))
                .task {
                    // Only start the synchronization once.
                    if syncManager.state == .idle {
                        await startSync()
                    }
                }
        }
    }

    private func startSync() async {
        await syncManager.synchronize(
            context: modelContext,
            tenantID: session.currentTenantID,
            services: services,
            api: session.api
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: AIAction.self, AgendaEvent.self, AgendaTask.self, FieldOption.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return RootView()
        .modelContainer(container)
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
}

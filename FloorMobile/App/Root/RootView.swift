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
    @State private var syncManager = SyncManager()

    var body: some View {
        switch session.state {
        case .loading:
            LoadingView(message: String(localized: "Loading…"))
        case .unauthenticated, .authenticating, .failed:
            LoginView()
        case .authenticated:
            syncedContent
        }
    }

    /// The pre-existing sync flow, shown once the user is signed in.
    @ViewBuilder
    private var syncedContent: some View {
        switch syncManager.state {
        case .finished:
            HomeView()
        case .failed(let message):
            LoadingView(message: message) {
                Task { await syncManager.synchronize(context: modelContext) }
            }
        case .idle, .syncing:
            LoadingView(message: String(localized: "Synchronizing data…"))
                .task {
                    // Only start the synchronization once.
                    if syncManager.state == .idle {
                        await syncManager.synchronize(context: modelContext)
                    }
                }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: AIAction.self, inMemory: true)
        .environment(AppSession(auth: .preview, api: .preview))
}

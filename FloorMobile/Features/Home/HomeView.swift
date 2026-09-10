//
//  HomeView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// The home screen: a summary of the sections a store advisor sees first.
/// Each section is its own view (owned by its feature), so it can grow (data,
/// states, navigation) without crowding this file.
struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                AIRecommendationsSection()
                NextAppointmentSection()
                TodaysTasksSection()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .refreshable { await reloadHomePage() }
        .ambientBackground()
    }

    /// Pull-to-refresh: re-syncs the home data. Mono-domain for now
    /// (AI actions); fans out to other sections as they gain data.
    private func reloadHomePage() async {
        await SessionSync.run(label: "Home reload", session: session, context: modelContext) {
            try await AIActionSync.synchronize(using: session.api, context: modelContext)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppSession(auth: .preview, api: .preview))
        .modelContainer(for: AIAction.self, inMemory: true)
}

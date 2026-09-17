//
//  HomeView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// The home screen: a summary of the sections a store advisor sees first.
/// Each section is its own view (owned by its feature), so it can grow (data,
/// states, navigation) without crowding this file.
struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
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
        .task { await loadHomePage() }
        .refreshable { await loadHomePage() }
        .ambientBackground()
        .appHeader {
            ToolbarItem(placement: .topBarTrailing) {
                AppHeaderButton(systemImage: "barcode.viewfinder", label: String(localized: "Scan")) {
                    AppLog.ui.info("Home: 'Scan' tapped in header")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                AppHeaderButton(systemImage: "plus", label: String(localized: "Add")) {
                    AppLog.ui.info("Home: 'Add' tapped in header")
                }
            }
        }
    }

    /// Loads the home data on appear and on pull-to-refresh: AI actions, events
    /// and tasks fan out concurrently, each on its own `@ModelActor`, under the
    /// session policy (expired session → purge + sign out). `api` and the
    /// actors are read on the main actor here, then captured by the child tasks.
    private func loadHomePage() async {
        let api = session.api
        let aiActions = services.aiActions
        let agenda = services.agenda
        await SessionSync.run(label: "Home", session: session, context: modelContext) {
            async let ai: Void = aiActions.synchronizePending(using: api)
            async let events: Void = agenda.synchronizeEvents(using: api)
            async let tasks: Void = agenda.synchronizeTasks(using: api)
            _ = try await (ai, events, tasks)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: AIAction.self, AgendaEvent.self, AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return HomeView()
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
        .environment(Router<HomeRoute>())
        .modelContainer(container)
}

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

    /// When the screen last loaded. `nil` until a load succeeds; it survives a
    /// push and a tab switch, since `HomeView`'s identity does.
    @State private var lastLoad: Date?

    /// How long a load stays good enough for the next appearance to skip it.
    private static let freshness: TimeInterval = 60

    /// What the cover has open, or `nil` when it is closed. Held by the page
    /// rather than by each section: only one cover can be up at a time, and one
    /// `switch` in one place is the whole list of what Home can open. The
    /// sections raise an intention; the page decides. Same shape as `AgendaView`.
    @State private var presenting: AgendaPresentation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                AIRecommendationsSection()
                NextAppointmentSection { presenting = .newEvent }
                TodaysTasksSection(
                    onCreate: { presenting = .newTask },
                    onSelect: { presenting = .task(id: $0.id) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        // Seeded with today: from Home, what is created is created for today.
        // The agenda seeds the same screens with the day it is showing.
        .fullScreenCover(item: $presenting) { presentation in
            AgendaPresentationScreen(presentation: presentation, date: .now)
        }
        // Re-entering the screen re-fires `.task`: SwiftUI cancels it when the
        // view disappears — which a push onto the Home stack does, as does
        // leaving the tab — and starts it again on the way back. Fetching three
        // endpoints because the user glanced at the agenda is waste: the store
        // is already right, since the write paths upsert what the server
        // returns. Only a load old enough to be worth redoing goes through.
        .task {
            guard Self.isStale(lastLoad) else { return }
            if await loadHomePage() { lastLoad = .now }
        }
        // Pull-to-refresh ignores the window: an explicit gesture must always
        // reach the server.
        .refreshable {
            if await loadHomePage() { lastLoad = .now }
        }
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
    ///
    /// - Returns: whether the load succeeded. A failure must not be recorded as
    ///   a fresh load, or one dropped connection would leave the screen on its
    ///   stale data for the whole freshness window.
    private func loadHomePage() async -> Bool {
        let api = session.api
        let aiActions = services.aiActions
        let agenda = services.agenda
        do {
            async let ai: Void = aiActions.synchronizePending(using: api)
            async let events: Void = agenda.synchronizeEvents(using: api)
            async let tasks: Void = agenda.synchronizeTasks(using: api)
            _ = try await (ai, events, tasks)
            return true
        } catch {
            // Swallowed on purpose: a refresh that fails leaves the screen on
            // what it already had. An expired session is not this function's
            // business — `APIClient` raises it and `RootView` acts on it.
            AppLog.ui.error("Home sync failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Whether a load done at `date` is old enough to redo.
    private static func isStale(_ date: Date?) -> Bool {
        guard let date else { return true }
        return Date.now.timeIntervalSince(date) >= freshness
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

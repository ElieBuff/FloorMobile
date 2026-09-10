//
//  AIRecommendationsSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// Home section surfacing AI recommendations synced from the API. Shows the
/// pending actions as a single-open accordion, or an empty card when there
/// are none.
struct AIRecommendationsSection: View {
    @Query(sort: \AIAction.createdAt, order: .reverse) private var actions: [AIAction]
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @State private var expansion = SingleExpansion<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "AI recommendations"),
                actionLabel: String(localized: "View all")
            ) {
                AppLog.ui.info("Home: 'View all' tapped in AI recommendations")
            }

            if actions.isEmpty {
                EmptySectionCard(
                    icon: { Image(systemName: "sparkles").foregroundStyle(Color(.textPrimary)) },
                    message: String(localized: "No recommendation yet")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(actions) { action in
                        AIActionRow(
                            action: action,
                            isExpanded: expansion.isOpen(action.id)
                        ) {
                            withAnimation(.snappy) { expansion.toggle(action.id) }
                        }
                    }
                }
            }
        }
        .task { await loadAIActions() }
    }

    /// Syncs the pending AI actions; `@Query` refreshes the list on save.
    private func loadAIActions() async {
        await SessionSync.run(label: "AI actions", session: session, context: modelContext) {
            try await AIActionSync.synchronize(using: session.api, context: modelContext)
        }
    }
}

#Preview("Populated") {
    let container = try! ModelContainer(
        for: AIAction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let now = Date(timeIntervalSince1970: 1_788_377_164)
    for i in 1...3 {
        container.mainContext.insert(AIAction(
            id: "0\(i)", agentKey: "contact-radar", type: "ANNIVERSARY_TRAVEL_WISHES",
            title: "Recommendation \(i)", reason: "A short reason explaining why this action matters.",
            statusRaw: "PENDING", createdAt: now.addingTimeInterval(Double(-i)),
            clientFirstName: "Elie", clientLastName: "Buff"
        ))
    }
    return AIRecommendationsSection()
        .modelContainer(container)
        .environment(AppSession(auth: .preview, api: .preview))
        .padding()
        .background(Color.black)
}

#Preview("Empty") {
    AIRecommendationsSection()
        .modelContainer(for: AIAction.self, inMemory: true)
        .environment(AppSession(auth: .preview, api: .preview))
        .padding()
        .background(Color.black)
}

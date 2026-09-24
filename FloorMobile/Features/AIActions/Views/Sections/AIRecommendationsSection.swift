//
//  AIRecommendationsSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// Home section surfacing AI recommendations synced from the API. Shows the
/// most recent pending actions as a single-open accordion, or an empty card
/// when there are none.
struct AIRecommendationsSection: View {
    /// How many recommendations the Home section surfaces (see-all shows the rest).
    private static let maxVisible = 3
    
    @Query(recentDescriptor) private var actions: [AIAction]
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
                    icon: { Image(systemName: "sparkles").foregroundStyle(Color(.OnCanvas.textPrimary)) },
                    message: String(localized: "No recommendation yet")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(actions) { action in
                        AIActionRow(
                            action: action,
                            isExpanded: expansion.isOpen(action.id),
                            onTap: { withAnimation(.snappy) { expansion.toggle(action.id) } },
                            onMessage: { AppLog.ui.info("Home: 'Message' tapped for AI action \(action.id, privacy: .private)") },
                            onCall: { AppLog.ui.info("Home: 'Call' tapped for AI action \(action.id, privacy: .private)") },
                            onCreateTask: { AppLog.ui.info("Home: 'Task' tapped for AI action \(action.id, privacy: .private)") },
                            onDismiss: { AppLog.ui.info("Home: 'Not now' tapped for AI action \(action.id, privacy: .private)") }
                        )
                    }
                }
            }
        }
    }

    /// Newest first, capped so the store never loads more than we display.
    private static var recentDescriptor: FetchDescriptor<AIAction> {
        var descriptor = FetchDescriptor<AIAction>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = maxVisible
        return descriptor
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
            client: ClientSummary(firstName: "Elie", lastName: "Buff")
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

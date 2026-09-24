//
//  TodaysTasksSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// The Home screen's "Today's tasks" block: the section title and "View agenda"
/// action over today's tasks, capped to a short list. A thin composition around
/// the reusable, header-less `DayTasksSection`.
struct TodaysTasksSection: View {
    /// How many tasks the Home section surfaces (see-all shows the rest).
    private static let maxVisible = 3

    /// What the empty card's button does, and what a tapped row does. Both are
    /// the page's business: it owns the one cover these open in.
    var onCreate: () -> Void = {}
    var onSelect: (AgendaTask) -> Void = { _ in }

    @Environment(Router<HomeRoute>.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Today's tasks"),
                actionLabel: String(localized: "View agenda")
            ) {
                router.push(.agenda(date: .now))
            }
            DayTasksSection(
                date: .now,
                limit: Self.maxVisible,
                // Home is a to-do list, not a record: what is done leaves it.
                // The agenda keeps the completed ones — that is where the day
                // is reviewed.
                completed: .hidden,
                emptyMessage: String(localized: "No task today"),
                onCreate: onCreate,
                onSelect: onSelect
            )
        }
    }
}

#Preview("Populated") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for i in 1...3 {
        container.mainContext.insert(AgendaTask(
            id: "0\(i)", statusRaw: "TO_DO", reasonRaw: "FOLLOW_UP", title: "Task \(i)",
            startDate: Date().addingTimeInterval(Double(i) * 3600),
            createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Elie", lastName: "Buff")
        ))
    }
    return TodaysTasksSection()
        .modelContainer(container)
        .environment(Router<HomeRoute>())
        // The rows tick through the session and the services.
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
        .padding()
        .background(Color.black)
}

#Preview("Empty") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return TodaysTasksSection()
        .modelContainer(container)
        .environment(Router<HomeRoute>())
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
        .padding()
        .background(Color.black)
}

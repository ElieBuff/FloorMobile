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
                emptyMessage: String(localized: "No task today")
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
            id: "0\(i)", statusRaw: "TODO", reasonRaw: "CALL", title: "Task \(i)",
            startDate: Date().addingTimeInterval(Double(i) * 3600),
            createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Elie", lastName: "Buff")
        ))
    }
    return TodaysTasksSection()
        .modelContainer(container)
        .environment(Router<HomeRoute>())
        .padding()
        .background(Color.black)
}

#Preview("Empty") {
    TodaysTasksSection()
        .modelContainer(for: AgendaTask.self, inMemory: true)
        .environment(Router<HomeRoute>())
        .padding()
        .background(Color.black)
}

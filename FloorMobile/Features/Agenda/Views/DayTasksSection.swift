//
//  DayTasksSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// The tasks for a given day (whole day: past and upcoming), rendered as a
/// single card of `TaskRow`s, or an empty card when there are none. Header-less
/// and date-driven so it can be reused wherever a day's tasks are shown — the
/// title belongs to the caller (e.g. `TodaysTasksSection`), as does the empty
/// message via `emptyMessage`. `limit` caps how many rows load; `nil` loads the
/// whole day.
struct DayTasksSection: View {
    private let emptyMessage: String
    @Query private var tasks: [AgendaTask]

    /// Builds the query for `date`'s whole day, soonest first, optionally capped
    /// so the store never loads more than we display.
    init(date: Date, limit: Int? = nil, emptyMessage: String = String(localized: "No task")) {
        self.emptyMessage = emptyMessage
        let startOfDay = date.startOfDay
        let startOfNextDay = date.startOfNextDay
        var descriptor = FetchDescriptor<AgendaTask>(
            predicate: #Predicate { $0.startDate >= startOfDay && $0.startDate < startOfNextDay },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        if let limit { descriptor.fetchLimit = limit }
        _tasks = Query(descriptor)
    }

    var body: some View {
        if tasks.isEmpty {
            EmptySectionCard(
                icon: { Image(systemName: "checklist").foregroundStyle(Color(.OnCanvas.textPrimary)) },
                message: emptyMessage,
                action: EmptySectionAction(label: String(localized: "Create task"), systemImage: "plus") {
                    AppLog.ui.info("Day tasks: 'Create task' tapped")
                }
            )
        } else {
            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    TaskRow(task: task) {
                        AppLog.ui.info("Day tasks: task tapped \(task.id, privacy: .private)")
                    }
                    if task.id != tasks.last?.id {
                        Rectangle()
                            .fill(Color(.OnSurface.borderSubtle))
                            .frame(height: 1)
                            .padding(.horizontal, 18)
                    }
                }
            }
            .cardStyle()
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
    return DayTasksSection(date: .now)
        .modelContainer(container)
        .padding()
        .background(Color.black)
}

#Preview("Empty") {
    DayTasksSection(date: .now)
        .modelContainer(for: AgendaTask.self, inMemory: true)
        .padding()
        .background(Color.black)
}

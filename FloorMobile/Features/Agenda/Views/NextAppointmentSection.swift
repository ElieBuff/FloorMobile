//
//  NextAppointmentSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// Home section showing the advisor's next appointment today.
struct NextAppointmentSection: View {
    @Query(nextTodayDescriptor) private var events: [AgendaEvent]
    @Environment(Router<HomeRoute>.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Next appointment"),
                actionLabel: String(localized: "View agenda")
            ) {
                router.push(.agenda(date: .now))
            }

            if let event = events.first {
                NextAppointmentCard(event: event) {
                    AppLog.ui.info("Home: 'Prepare' tapped in Next appointment")
                }
            } else {
                EmptySectionCard(
                    icon: { Image(systemName: "calendar").foregroundStyle(Color(.OnCanvas.textPrimary)) },
                    message: String(localized: "No appointment today"),
                    action: EmptySectionAction(label: String(localized: "View agenda")) {
                        router.push(.agenda(date: .now))
                    }
                )
            }
        }
    }

    /// The next upcoming event today (now → end of day), soonest first.
    private static var nextTodayDescriptor: FetchDescriptor<AgendaEvent> {
        let now = Date()
        let startOfTomorrow = now.startOfNextDay
        var descriptor = FetchDescriptor<AgendaEvent>(
            predicate: #Predicate { $0.startDate >= now && $0.startDate < startOfTomorrow },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}

#Preview("With appointment") {
    let container = try! ModelContainer(
        for: AgendaEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(AgendaEvent(
        id: "1", statusRaw: "PLANNED", reasonRaw: "APPOINTMENT",
        title: "Essayage collection automne",
        startDate: Date().addingTimeInterval(3600), duration: 45,
        createdAt: .now, updatedAt: .now,
        client: ClientSummary(firstName: "Raphaël", lastName: "Van den Berg")
    ))
    return NextAppointmentSection()
        .modelContainer(container)
        .environment(Router<HomeRoute>())
        .padding()
        .background(Color.black)
}

#Preview("Empty") {
    NextAppointmentSection()
        .modelContainer(for: AgendaEvent.self, inMemory: true)
        .environment(Router<HomeRoute>())
        .padding()
        .background(Color.black)
}

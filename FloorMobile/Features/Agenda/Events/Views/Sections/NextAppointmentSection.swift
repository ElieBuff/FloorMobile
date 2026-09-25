//
//  NextAppointmentSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// Home section showing the advisor's next appointment today.
///
/// ## Staying current
///
/// Which appointment is "next" is a question for the clock, and the clock is
/// read on every minute boundary by `TimelineView(.everyMinute)` — the same
/// mechanism `DayEventsSection` uses, for the same reasons. A `@Query` whose
/// predicate captured `Date()` once kept naming an appointment long after it
/// had started: `HomeView` keeps its identity across a push and a tab switch,
/// so that predicate was built once per session and never again.
///
/// The query is therefore only a coarse window — everything from the start of
/// the day the screen was built — and `DayTimeline.nextAppointment` picks the
/// right one inside it, checking the day against `now` itself so midnight is
/// handled too.
struct NextAppointmentSection: View {
    /// What the empty card's button does — booking an appointment, which the
    /// page opens in its cover. The header's "View agenda" stays a push, so a
    /// day with nothing on it offers both: create one, or go look at the week.
    var onCreate: () -> Void = {}

    @Query(fromTodayDescriptor) private var events: [AgendaEvent]
    @Environment(Router<HomeRoute>.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Next appointment"),
                actionLabel: String(localized: "View agenda")
            ) {
                router.push(.agenda(date: .now))
            }

            TimelineView(.everyMinute) { context in
                if let event = DayTimeline.nextAppointment(in: events, at: context.date) {
                    NextAppointmentCard(event: event, onPrepare: {
                        AppLog.ui.info("Home: 'Prepare' tapped in Next appointment")
                    }, now: context.date)
                } else {
                    EmptySectionCard(
                        icon: { Image(systemName: "calendar").foregroundStyle(Color(.OnCanvas.textPrimary)) },
                        message: String(localized: "No appointment today"),
                        // "New Event", not "View agenda": every button that books an
                        // appointment carries the same words, wherever it sits, and
                        // it does what it says. Sending the advisor to the agenda to
                        // then find the "+" was one hop too many.
                        action: EmptySectionAction(
                            label: String(localized: "New Event"),
                            systemImage: "plus",
                            handler: onCreate
                        )
                    )
                }
            }
        }
    }

    /// Every event from the start of the day this screen was built, soonest
    /// first. Deliberately wider than "the next one today": the choice is made
    /// against the live clock in `body`, and this only keeps the store from
    /// handing over the whole agenda. A lower bound in the past can only add
    /// rows the day check then drops — it can never hide today's.
    private static var fromTodayDescriptor: FetchDescriptor<AgendaEvent> {
        let startOfToday = Date.now.startOfDay
        return FetchDescriptor<AgendaEvent>(
            predicate: #Predicate { $0.startDate >= startOfToday },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
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

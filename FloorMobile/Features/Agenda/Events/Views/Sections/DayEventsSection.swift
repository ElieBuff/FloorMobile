//
//  DayEventsSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// A day's appointments as a rail of `EventRow`s, with the current-time marker
/// threaded through them — or an empty card when the day holds nothing.
///
/// Header-less and date-driven, like `DayTasksSection`: the title belongs to
/// whoever places it.
///
/// ## Staying current
///
/// The rail is alive: the marker moves and appointments grey out as the day
/// passes, without anyone touching the screen. `TimelineView(.everyMinute)`
/// drives that, and it is worth saying why it rather than a `Timer`.
///
/// A timer started at an arbitrary moment fires on an arbitrary phase, so the
/// rule could still read 11:19 most of a minute after 11:20. It also keeps
/// firing behind a pushed screen or a backgrounded app, and has to be cancelled
/// by hand. `.everyMinute` fires *on the minute boundary*, suspends itself when
/// the view is not on screen, and needs no lifecycle code at all — the same
/// reasoning that drives `BreathingDot`.
///
/// One clock for both answers also means the marker can never slide past an
/// appointment that has not yet greyed: they are produced in the same pass.
struct DayEventsSection: View {
    private let date: Date
    private let emptyMessage: String
    /// What the empty card's button does. Empty by default, like `onSelect`:
    /// the section shows a day, it does not decide what a day without
    /// appointments leads to — the caller owns the cover it opens in.
    private let onCreate: () -> Void
    /// What a tapped appointment does. Empty by default: the caller decides —
    /// the agenda opens the composer on it, Home has nowhere to go yet.
    private let onSelect: (AgendaEvent) -> Void
    @Query private var events: [AgendaEvent]

    /// Builds the query for `date`'s whole day, soonest first.
    init(
        date: Date,
        emptyMessage: String = String(localized: "No appointment"),
        onCreate: @escaping () -> Void = {},
        onSelect: @escaping (AgendaEvent) -> Void = { _ in }
    ) {
        self.date = date
        self.emptyMessage = emptyMessage
        self.onCreate = onCreate
        self.onSelect = onSelect
        let startOfDay = date.startOfDay
        let startOfNextDay = date.startOfNextDay
        _events = Query(
            FetchDescriptor<AgendaEvent>(
                predicate: #Predicate { $0.startDate >= startOfDay && $0.startDate < startOfNextDay },
                sortBy: [SortDescriptor(\.startDate, order: .forward)]
            )
        )
    }

    var body: some View {
        if events.isEmpty {
            EmptySectionCard(
                icon: { Image(systemName: "calendar").foregroundStyle(Color(.OnCanvas.textPrimary)) },
                message: emptyMessage,
                action: EmptySectionAction(
                    label: String(localized: "New Event"),
                    systemImage: "plus",
                    handler: onCreate
                )
            )
        } else {
            TimelineView(.everyMinute) { context in
                let items = DayTimeline.items(events: events, now: context.date, day: date)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        switch item {
                        case .event(let event, let standing, let rule):
                            EventRow(event: event, standing: standing, rule: rule) { onSelect(event) }
                        case .now:
                            NowMarker(date: context.date)
                        }
                    }
                }
                // Keyed on the items, which deliberately ignore the clock: the
                // list only compares unequal when something actually moved or
                // changed state, so a quiet minute animates nothing.
                .animation(.smooth, value: items)
            }
        }
    }
}

// MARK: - Previews

#Preview("A day in progress") {
    let container = try! ModelContainer(
        for: AgendaEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let calendar = Calendar.current
    let at: (Int, Int) -> Date = { hour, minute in
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }
    let people = [
        ("1", "PLANNED", "BACK_IN_STOCK", "Inès", "Haddad", "Retrait commande", at(9, 30), 30),
        ("2", "CANCELLED", "FOLLOW_UP", "Marie", "Dupont", "Essayage", at(10, 30), 30),
        ("3", "CONFIRMED", "FOLLOW_UP", "Salomé", "Kaliny", "Essayage", at(14, 0), 60),
        ("4", "PLANNED", "BIRTHDAY", "Léa", "Bonnet", "Découverte", at(16, 0), 30),
    ]
    for (id, status, reason, first, last, title, start, duration) in people {
        container.mainContext.insert(AgendaEvent(
            id: id, statusRaw: status, reasonRaw: reason, meetingTypeRaw: "IN_PERSON",
            title: title, startDate: start, duration: duration,
            createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: first, lastName: last, segment: "Gold")
        ))
    }
    return ScrollView {
        DayEventsSection(date: .now)
            .padding(16)
    }
    .modelContainer(container)
    .ambientBackground()
}

#Preview("Empty day") {
    DayEventsSection(date: .now, emptyMessage: String(localized: "No appointment today"))
        .padding(16)
        .modelContainer(for: AgendaEvent.self, inMemory: true)
        .ambientBackground()
}

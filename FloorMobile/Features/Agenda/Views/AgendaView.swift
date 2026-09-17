//
//  AgendaView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// The agenda screen, reached from Home's "View agenda" links.
///
/// The calendar is pinned above the day's content rather than scrolling with it:
/// it owns a drag gesture of its own, which a surrounding `ScrollView` would
/// fight over. The route's date only seeds the selection — from then on the
/// calendar drives it.
struct AgendaView: View {
    let date: Date

    @State private var selection: Date
    @Query(sort: \AgendaEvent.startDate) private var events: [AgendaEvent]

    init(date: Date) {
        self.date = date
        _selection = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            CollapsibleCalendar(
                selection: $selection,
                daysWithEvents: events.map(\.startDate)
            )
            .padding(.horizontal, 16)

            // Sized to its own content and pinned directly under the calendar,
            // so the card's growth pushes it down point for point. Left to
            // centre itself in whatever space remains, it would drift at half
            // the speed — and a calendar that expands without moving anything
            // else reads as a widget floating over the screen rather than as
            // part of it.
            ContentUnavailableView(
                String(localized: "Agenda"),
                systemImage: "calendar",
                description: Text(selection, format: .dateTime.weekday(.wide).day().month(.wide))
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 32)

            Spacer(minLength: 0)
        }
        // Pinned to the top: left to centre itself, the stack would drift upward
        // as the calendar expands, sliding under the navigation bar.
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .ambientBackground()
        .navigationTitle(String(localized: "Agenda"))
        // Inline, not large: a large title is drawn over this screen rather than
        // above it (there is no scroll view for it to collapse into), so the
        // calendar ended up underneath the word "Agenda".
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: AgendaEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for offset in [0, 1, 3, 8, 14] {
        container.mainContext.insert(AgendaEvent(
            id: "\(offset)", statusRaw: "PLANNED", reasonRaw: "APPOINTMENT",
            title: "Rendez-vous \(offset)",
            startDate: Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now,
            duration: 30, createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Salomé", lastName: "Kaliny")
        ))
    }
    return NavigationStack {
        AgendaView(date: .now)
    }
    .modelContainer(container)
}

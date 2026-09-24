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
    /// What the cover has open, or `nil` when it is closed. The type is shared
    /// with Home, which presents the same objects — see `AgendaPresentation`.
    @State private var presenting: AgendaPresentation?

    // Unsorted on purpose: the only consumer is a set of days.
    @Query private var events: [AgendaEvent]
    @Query private var tasks: [AgendaTask]

    /// Days the calendar dots: anything in the agenda counts, event or task.
    /// Raw days — the calendar de-duplicates them itself.
    private var daysWithActivity: [Date] {
        events.map(\.agendaDay) + tasks.map(\.agendaDay)
    }

    init(date: Date) {
        self.date = date
        _selection = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            CollapsibleCalendar(
                selection: $selection,
                daysWithEvents: daysWithActivity
            )
            .padding(.horizontal, 16)

            // The day's content is pinned directly under the calendar, so the
            // calendar's growth pushes it down point for point. Left to centre
            // itself in whatever space remains, it would drift at half the
            // speed — and a calendar that expands without moving anything else
            // reads as a widget floating over the screen rather than as part
            // of it. The scroll view takes the remaining space (long task
            // lists scroll) without wrapping the calendar, whose own drag
            // gesture it would fight over.
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: String(localized: "Appointments"))
                    DayEventsSection(
                        date: selection,
                        // The empty card's button and the toolbar's "+" open the
                        // same composer, on the same day.
                        onCreate: { presenting = .newEvent },
                        onSelect: { presenting = .event(id: $0.id) }
                    )

                    SectionHeader(title: String(localized: "Tasks"))
                        .padding(.top, 10)
                    DayTasksSection(
                        date: selection,
                        // The empty card's button and the toolbar's "+" open
                        // the same composer, on the same day.
                        onCreate: { presenting = .newTask },
                        onSelect: { presenting = .task(id: $0.id) }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // Pinned to the top: left to centre itself, the stack would drift upward
        // as the calendar expands, sliding under the navigation bar.
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .ambientBackground()
        .navigationTitle(String(localized: "Agenda"))
        // Inline, not large: there is no scroll view here for a large title to
        // collapse into, so it draws over this screen rather than above it and
        // the calendar lands underneath the word "Agenda".
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // The choice of what to create is made here, before the cover
                // opens — so the cover arrives on the thing that was asked for
                // instead of asking again.
                Menu {
                    Button {
                        presenting = .newEvent
                    } label: {
                        Label(String(localized: "New Event"), systemImage: "calendar")
                    }

                    Button {
                        presenting = .newTask
                    } label: {
                        Label(String(localized: "New Task"), systemImage: "checklist")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                }
                .accessibilityLabel(String(localized: "Add"))
            }
        }
        // The composers are seeded with the day on screen, not with today.
        .fullScreenCover(item: $presenting) { presentation in
            AgendaPresentationScreen(presentation: presentation, date: selection)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: AgendaEvent.self, AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let calendar = Calendar.current
    // Today, around the clock, so the rail shows past, present and future —
    // and the current-time marker lands somewhere in the middle of them.
    let today: [(String, String, String, String, String, Int, Int)] = [
        ("t1", "PLANNED", "BACK_IN_STOCK", "Inès", "Haddad", 9, 30),
        ("t2", "CANCELLED", "FOLLOW_UP", "Marie", "Dupont", 11, 0),
        ("t3", "CONFIRMED", "FOLLOW_UP", "Salomé", "Kaliny", 15, 0),
        ("t4", "PLANNED", "BIRTHDAY", "Léa", "Bonnet", 18, 30),
    ]
    for (id, status, reason, first, last, hour, minute) in today {
        container.mainContext.insert(AgendaEvent(
            id: id, statusRaw: status, reasonRaw: reason, meetingTypeRaw: "IN_PERSON",
            title: "Essayage",
            startDate: calendar.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now,
            duration: 45, createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: first, lastName: last, segment: "Gold")
        ))
    }
    // A few other days, only so the calendar has dots to show.
    for offset in [1, 3, 8, 14] {
        container.mainContext.insert(AgendaEvent(
            id: "d\(offset)", statusRaw: "PLANNED", reasonRaw: "VIP_EVENT",
            title: "Rendez-vous",
            startDate: calendar.date(byAdding: .day, value: offset, to: .now) ?? .now,
            duration: 30, createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Salomé", lastName: "Kaliny")
        ))
    }
    for i in 1...3 {
        container.mainContext.insert(AgendaTask(
            id: "task-\(i)", statusRaw: "TO_DO", reasonRaw: "FOLLOW_UP", title: "Task \(i)",
            startDate: Date().addingTimeInterval(Double(i) * 3600),
            createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Elie", lastName: "Buff")
        ))
    }
    return NavigationStack {
        AgendaView(date: .now)
    }
    // The composers save through the session and the services; the rows open
    // their detail in the agenda's own cover.
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
    .modelContainer(container)
}

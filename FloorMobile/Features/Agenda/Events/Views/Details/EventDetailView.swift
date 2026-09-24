//
//  EventDetailView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// One appointment, read-only, opened from the agenda in its cover. The event
/// half of `TaskDetailView`, which spells out why the screen takes an id and
/// queries it rather than being handed the row.
struct EventDetailView: View {
    @Query private var events: [AgendaEvent]

    init(id: String) {
        var descriptor = FetchDescriptor<AgendaEvent>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        _events = Query(descriptor)
    }

    var body: some View {
        if let event = events.first {
            fields(for: event)
                // The form is pushed onto the cover's own stack, not raised as
                // a second modal over this one.
                .detailScreen(title: String(localized: "Event")) {
                    EventComposerView(event: event)
                }
        } else {
            missing
        }
    }

    private func fields(for event: AgendaEvent) -> some View {
        List {
            Section {
                DetailStackedRow(
                    label: event.reason.displayLabel,
                    text: event.title,
                    emphasis: .title
                )
                .listRowInsets(.cardRow)
            }

            Section {
                DetailRow(
                    label: String(localized: "Client"),
                    value: event.clientDisplayName ?? "—"
                )
                .listRowInsets(.cardRow)

                // Hidden when absent, unlike the client: the server genuinely
                // leaves this one unset, so an empty value would report a gap
                // that is not one.
                if let type = event.meetingType?.displayLabel {
                    DetailRow(label: String(localized: "Type"), value: type)
                        .listRowInsets(.cardRow)
                }
            }

            Section {
                // One string, formatted whole. The mockup separates the day and
                // the hour with a "·", which is a decision no locale asked for.
                DetailRow(
                    label: String(localized: "Start"),
                    value: event.startDate.formatted(date: .abbreviated, time: .shortened)
                )
                .listRowInsets(.cardRow)

                DetailRow(
                    label: String(localized: "Duration"),
                    value: Duration.minutes(event.duration).hoursAndMinutes
                )
                .listRowInsets(.cardRow)

                // The API stores an instant; nobody thinks in instants. Back to
                // the offset the advisor picked, and out as "30 min before".
                DetailRow(
                    label: String(localized: "Reminder"),
                    value: ReminderOffset.label(
                        ReminderOffset.minutes(from: event.reminderDate, before: event.startDate)
                    )
                )
                .listRowInsets(.cardRow)
            }

            if let note = event.eventDescription, !note.isEmpty {
                Section {
                    DetailStackedRow(label: String(localized: "Note"), text: note)
                        .listRowInsets(.cardRow)
                }
            }
        }
    }

    private var missing: some View {
        ContentUnavailableView {
            Label {
                Text("Appointment not found")
            } icon: {
                Image(systemName: "calendar")
            }
        } description: {
            Text("It may have been cancelled or removed on another device.")
        }
        // The same chrome, minus the "Edit": there is nothing left to open a
        // form on.
        .detailScreen(title: String(localized: "Event"))
    }
}

// MARK: - Previews

#Preview {
    let container = try! ModelContainer(
        for: AgendaEvent.self, FieldOption.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let start = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: .now) ?? .now
    container.mainContext.insert(AgendaEvent(
        id: "e-1", statusRaw: "CONFIRMED", reasonRaw: "VIP_EVENT", meetingTypeRaw: "IN_PERSON",
        title: "Autumn fitting",
        eventDescription: """
            Loyal client, prefers the first-floor salon. Bring the tan belt and \
            the pearl minaudière to the room before she arrives.
            """,
        startDate: start,
        duration: 60,
        reminderDate: start.addingTimeInterval(-30 * 60),
        createdAt: .now, updatedAt: .now,
        client: ClientSummary(firstName: "Salomé", lastName: "Kaliny", segment: "Gold")
    ))

    return NavigationStack {
        EventDetailView(id: "e-1")
    }
    .modelContainer(container)
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
    .tint(Color(.Base.ink))
}

#Preview("No type, no note, no reminder") {
    let container = try! ModelContainer(
        for: AgendaEvent.self, FieldOption.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(AgendaEvent(
        id: "e-2", statusRaw: "PLANNED", reasonRaw: "BIRTHDAY",
        title: "Anniversaire",
        startDate: .now, duration: 30, createdAt: .now, updatedAt: .now
    ))

    return NavigationStack {
        EventDetailView(id: "e-2")
    }
    .modelContainer(container)
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
    .tint(Color(.Base.ink))
}

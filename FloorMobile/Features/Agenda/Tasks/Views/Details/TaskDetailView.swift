//
//  TaskDetailView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// One task, read-only, opened from the agenda in its cover.
///
/// Takes an id and looks the task up itself, because `HomeRoute` carries values
/// and never model objects. That is also what keeps the screen safe to leave
/// open: `@Query` is live, so a sync that prunes the row empties it and this
/// says the task is gone rather than reading a deleted object. A one-shot
/// `fetch` would hand back a single value instead of an array, but it would
/// not notice the deletion.
///
/// Read-only on purpose. "Edit" pushes the composer that already knows how to
/// change a task; a second set of fields here would be a second place to keep
/// in step with the API.
struct TaskDetailView: View {
    @Query private var tasks: [AgendaTask]

    init(id: String) {
        var descriptor = FetchDescriptor<AgendaTask>(predicate: #Predicate { $0.id == id })
        // `id` is unique, so there is at most one — said out loud rather than
        // left to the predicate.
        descriptor.fetchLimit = 1
        _tasks = Query(descriptor)
    }

    var body: some View {
        if let task = tasks.first {
            fields(for: task)
                // The form is pushed onto the cover's own stack, not raised as
                // a second modal over this one.
                .detailScreen(title: String(localized: "Task")) {
                    TaskComposerView(task: task)
                }
        } else {
            missing
        }
    }

    private func fields(for task: AgendaTask) -> some View {
        List {
            Section {
                // The label is the reason — a value, where every other label on
                // the screen is a fixed word.
                DetailStackedRow(
                    label: task.reason.displayLabel,
                    text: task.title,
                    emphasis: .title
                )
                .listRowInsets(.cardRow)
            }

            Section {
                // "—" rather than a hidden row: a task that is for nobody is
                // worth seeing, and the empty value is how you see it.
                DetailRow(
                    label: String(localized: "Client"),
                    value: task.clientDisplayName ?? "—"
                )
                .listRowInsets(.cardRow)

                // A day, not a moment: a task is due *on* a date, which is also
                // all the composer offers to pick.
                DetailRow(
                    label: String(localized: "Due date"),
                    value: task.startDate.formatted(date: .abbreviated, time: .omitted)
                )
                .listRowInsets(.cardRow)

                DetailRow(
                    label: String(localized: "Created"),
                    value: task.createdAt.formatted(date: .abbreviated, time: .omitted)
                )
                .listRowInsets(.cardRow)
            }

            // No note, no card. An empty "Note" heading says nothing twice.
            if let note = task.taskDescription, !note.isEmpty {
                Section {
                    DetailStackedRow(label: String(localized: "Note"), text: note)
                        .listRowInsets(.cardRow)
                }
            }

            // The one row on this screen that writes. Last, because it is the
            // thing you come back to a task to do — everything above is what
            // you read on the way to it.
            Section {
                DetailStackedRow(label: String(localized: "Status")) {
                    TaskStatusSection(id: task.id, status: task.status)
                }
                .listRowInsets(.cardRow)
            }
        }
    }

    /// Reachable while the screen is open: a refresh sweeps the rows the server
    /// no longer returns, and this one may be among them.
    private var missing: some View {
        ContentUnavailableView {
            Label {
                Text("Task not found")
            } icon: {
                Image(systemName: "checklist")
            }
        } description: {
            Text("It may have been completed or removed on another device.")
        }
        // The same chrome, minus the "Edit": there is nothing left to open a
        // form on.
        .detailScreen(title: String(localized: "Task"))
    }
}

// MARK: - Previews

#Preview {
    let container = try! ModelContainer(
        for: AgendaTask.self, FieldOption.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(AgendaTask(
        id: "t-1", statusRaw: "TO_DO", reasonRaw: "FOLLOW_UP",
        title: "Call about the Solène order",
        taskDescription: """
            She was torn between the 38 and the 40. Have both sizes ready in the \
            fitting room — and pull the matching belt in tan.
            """,
        startDate: .now,
        createdAt: .now.addingTimeInterval(-2 * 86_400),
        updatedAt: .now,
        client: ClientSummary(firstName: "Salomé", lastName: "Kaliny", segment: "Gold")
    ))

    return NavigationStack {
        TaskDetailView(id: "t-1")
    }
    .modelContainer(container)
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
    .tint(Color(.Base.ink))
}

#Preview("Swept while open") {
    NavigationStack {
        TaskDetailView(id: "gone")
    }
    .modelContainer(for: AgendaTask.self, inMemory: true)
    .tint(Color(.Base.ink))
}

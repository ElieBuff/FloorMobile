//
//  TaskComposerView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// The form that creates a task: the draft, the fields, and what confirming
/// does.
///
/// It owns the draft rather than passing one down from above, because the
/// confirm button is right here in its own chrome — `composerScreen` reads
/// `draft.isValid` to gate it. And it is its own type rather than a branch of
/// a shared composer: the kind is chosen at the "+" before this ever opens, so
/// nothing here needs to know that events exist.
///
/// The fields are built on `List`, one `Section` per card, for the reason
/// `EventComposerView` sets out: a system control only behaves like a form row
/// inside a list. Three sections, the same silhouette as the event sheet — what
/// the task *is*, who and when, the note.
struct TaskComposerView: View {
    @State private var draft: TaskDraft
    /// The draft as the form opened on it, and the only thing `isDirty`
    /// compares against — which is what decides whether leaving has to ask.
    private let original: TaskDraft
    /// Which initializer was used, because the two *are* the two ways in: "+"
    /// opens this form as the first screen of its cover, and a detail pushes it
    /// onto one.
    private let placement: ComposerScreen.Placement

    /// While the save is in flight: the confirm button waits rather than
    /// letting a second tap file a second task.
    @State private var isSaving = false
    @State private var alert: FloorAlert?

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    /// The day the agenda is showing — the draft's due date starts there, so
    /// "+" while browsing next Tuesday does not file something for today.
    init(date: Date) {
        let draft = TaskDraft(day: date)
        _draft = State(initialValue: draft)
        original = draft
        placement = .root
    }

    /// Opens the form on a task from the agenda, fields already filled.
    init(task: AgendaTask) {
        let draft = TaskDraft(task: task)
        _draft = State(initialValue: draft)
        original = draft
        placement = .pushed
    }

    /// Whether an existing task is being edited — the draft's `id` says so, and
    /// it is the same thing that turns the save into a `PUT`.
    private var isEditing: Bool { draft.id != nil }

    var body: some View {
        fields
            .composerScreen(
                title: isEditing ? String(localized: "Edit Task") : String(localized: "New Task"),
                placement: placement,
                canSave: draft.isValid,
                isDirty: draft != original,
                isSaving: isSaving
            ) {
                save()
            }
            .floorAlert($alert)
    }

    // MARK: - Fields

    private var fields: some View {
        List {
            Section {
                FormTitleRow(
                    label: String(localized: "Title"),
                    text: $draft.title,
                    onDictate: { AppLog.ui.info("Task form: dictate title") }
                )
                .listRowInsets(EdgeInsets())

                FormPushRow(
                    label: String(localized: "Reason"),
                    value: draft.reason?.displayLabel ?? "",
                    placeholder: String(localized: "Choose a reason")
                ) {
                    ReasonPickerView(selection: $draft.reason, key: .taskReason)
                }
                .listRowInsets(.cardRow)
            }

            Section {
                FormPushRow(
                    label: String(localized: "Client"),
                    value: draft.clientName,
                    placeholder: String(localized: "Choose a client")
                ) {
                    ClientPickerView(selection: $draft.clientName)
                }
                .listRowInsets(.cardRow)

                // A day, not a moment: a task is due *on* a date, and asking
                // for an hour it does not have invites a meaningless answer.
                DatePicker(selection: $draft.dueDate, displayedComponents: .date) {
                    FieldLabel(String(localized: "Due date"))
                }
                .listRowInsets(.cardRow)
            }

            Section {
                FormNoteRow(
                    text: $draft.note,
                    prompt: String(localized: "Notes"),
                    onDictate: { AppLog.ui.info("Task form: dictate note") }
                )
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .listRowBackground(Color(.OnCanvas.surface))
        .listRowSeparatorTint(Color(.OnSurface.borderSubtle))
        // The list paints its own grey ground; the screen already has one.
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Saving

    /// Sends the form, and closes only once the server has the task.
    ///
    /// Out to the API first, never into the local store on its own: the store
    /// is mark-and-sweep, so a row the server has never heard of would be
    /// pruned by the next refresh and the advisor would watch their task
    /// disappear. `AgendaService` stores what comes back instead.
    ///
    /// On failure the sheet stays up with what was typed still in it — a sheet
    /// that dismissed itself would take the advisor's words with it, and leave
    /// them unsure whether anything was saved.
    private func save() {
        guard !isSaving else { return }
        isSaving = true

        // Read off the main actor's state here, then hand the values to the
        // child task — the same shape as `HomeView.loadHomePage()`.
        let api = session.api
        let agenda = services.agenda
        let draft = draft

        Task {
            do {
                try await agenda.saveTask(draft, using: api)
                dismiss()
            } catch {
                isSaving = false
                alert = FloorAlert(
                    kind: .error,
                    title: isEditing
                        ? String(localized: "Task not saved")
                        : String(localized: "Task not created"),
                    message: error.localizedDescription,
                    primary: AlertAction(label: String(localized: "Try again")) { save() },
                    secondary: AlertAction(label: String(localized: "Close"), emphasis: .quiet)
                )
            }
        }
    }
}

// MARK: - Previews

// The chrome no longer carries a stack, so the presenter provides one — here,
// the preview. Rendered directly rather than through a presentation, which a
// preview would snapshot mid-animation.
#Preview {
    // No `@Query` in this view, but the reason picker it pushes has one — and
    // saving needs the session and the services, injected at the root in the app.
    let container = try! ModelContainer(
        for: FieldOption.self, AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return NavigationStack {
        TaskComposerView(date: .now)
    }
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
    .modelContainer(container)
    .tint(Color(.Base.ink))
}

//
//  EventComposerView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// The form that books an appointment: the draft, the fields, and what
/// confirming does.
///
/// It owns the draft rather than taking one from above, because the confirm
/// button is right here in its own chrome — `composerScreen` reads
/// `draft.isValid` to gate it. Its own type rather than a branch of a shared
/// composer: the kind is chosen at the "+" before this ever opens, so nothing
/// here needs to know that tasks exist.
///
/// The fields are built on `List`, one `Section` per card. That is not a styling
/// preference — a system control only behaves like a form row *inside* a list.
/// Out of one, `Picker` and `DatePicker` lose the full-row tap target, the menu
/// that drops from the trailing edge, the reflow that keeps a long value inside
/// its card at accessibility text sizes, and the keyboard avoidance that lifts
/// the focused field.
struct EventComposerView: View {
    @State private var draft: EventDraft
    /// The draft as the form opened on it, and the only thing `isDirty`
    /// compares against — which is what decides whether leaving has to ask.
    private let original: EventDraft
    /// Which initializer was used, because the two *are* the two ways in: "+"
    /// opens this form as the first screen of its cover, and a detail pushes it
    /// onto one.
    private let placement: ComposerScreen.Placement

    /// While the save is in flight: the confirm button waits rather than
    /// letting a second tap book a second appointment.
    @State private var isSaving = false
    @State private var alert: FloorAlert?

    /// `event.meetingType`, as the server currently allows it. A field with a
    /// fixed list of choices is not the same thing as a field with a
    /// *hard-coded* one: `duration` and `reminder` below are ours to decide,
    /// the meeting type is the backend's, and reading it from the store is what
    /// keeps the form honest the day a third kind of appointment appears.
    @Query(FieldOption.descriptor(for: .eventMeetingType)) private var meetingTypeOptions: [FieldOption]

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    /// The day the agenda is showing — the draft starts there.
    init(date: Date) {
        // A new appointment gets the default hour; `init(event:)` keeps the one
        // the appointment already has.
        let draft = EventDraft(day: EventDraft.defaultStart(on: date))
        _draft = State(initialValue: draft)
        original = draft
        placement = .root
    }

    /// Opens the form on an appointment from the agenda, fields already filled.
    init(event: AgendaEvent) {
        let draft = EventDraft(event: event)
        _draft = State(initialValue: draft)
        original = draft
        placement = .pushed
    }

    /// Whether an existing appointment is being edited — the draft's `id` says
    /// so, and it is the same thing that turns the save into a `PUT`.
    private var isEditing: Bool { draft.id != nil }

    private var meetingTypes: [MeetingType] {
        let offered = meetingTypeOptions.resolved(fallback: MeetingType.selectable)
        // Widened only when the appointment carries a type the server no
        // longer offers; there is nothing to widen when it carries none.
        return draft.meetingType.map { offered.including($0) } ?? offered
    }

    /// Ours to decide, so the list is a constant — widened the same way as the
    /// server's, since an appointment booked elsewhere can carry a duration
    /// this form does not offer.
    private var durations: [Int] {
        EventDraft.durations.including(draft.duration).sorted()
    }

    /// Sorted with "none" first, as the constant list has it.
    private var reminderOffsets: [Int?] {
        ReminderOffset.selectable.including(draft.reminderOffset)
            .sorted { ($0 ?? -1) < ($1 ?? -1) }
    }

    var body: some View {
        fields
            .composerScreen(
                title: isEditing ? String(localized: "Edit Event") : String(localized: "New Event"),
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
                    onDictate: { AppLog.ui.info("Event form: dictate title") }
                )
               .listRowInsets(EdgeInsets())

                FormPushRow(
                    label: String(localized: "Reason"),
                    value: draft.reason?.displayLabel ?? "",
                    placeholder: String(localized: "Choose a reason")
                ) {
                    ReasonPickerView(selection: $draft.reason, key: .eventReason)
                }
                .listRowInsets(.cardRow)

                Picker(selection: $draft.meetingType) {
                    ForEach(meetingTypes, id: \.self) { type in
                        // Tagged as an optional, to match the selection's type.
                        Text(type.displayLabel).tag(Optional(type))
                    }
                } label: {
                    FieldLabel(String(localized: "Type"))
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

                DatePicker(
                    selection: $draft.startDate,
                    displayedComponents: [.date, .hourAndMinute]
                ) {
                    FieldLabel(String(localized: "Start"))
                }
                .listRowInsets(.cardRow)

                Picker(selection: $draft.duration) {
                    ForEach(durations, id: \.self) { minutes in
                        Text(Duration.minutes(minutes).hoursAndMinutes).tag(minutes)
                    }
                } label: {
                    FieldLabel(String(localized: "Duration"))
                }
                .listRowInsets(.cardRow)

                Picker(selection: $draft.reminderOffset) {
                    ForEach(reminderOffsets, id: \.self) { offset in
                        Text(ReminderOffset.label(offset)).tag(offset)
                    }
                } label: {
                    FieldLabel(String(localized: "Reminder"))
                }
                .listRowInsets(.cardRow)
            }

            Section {
                FormNoteRow(
                    text: $draft.note,
                    prompt: String(localized: "Notes"),
                    onDictate: { AppLog.ui.info("Event form: dictate note") }
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

    /// Sends the form, and closes only once the server has the appointment —
    /// the event half of `TaskComposerView.save()`, which spells out why
    /// nothing is written locally on its own and why a failure keeps the sheet
    /// up. The `reminderDate` the draft derives from the chosen offset is what
    /// the request carries.
    private func save() {
        guard !isSaving else { return }
        isSaving = true

        let api = session.api
        let agenda = services.agenda
        let draft = draft

        Task {
            do {
                try await agenda.saveEvent(draft, using: api)
                dismiss()
            } catch {
                isSaving = false
                alert = FloorAlert(
                    kind: .error,
                    title: isEditing
                        ? String(localized: "Appointment not saved")
                        : String(localized: "Appointment not booked"),
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
    let container = try! ModelContainer(
        for: FieldOption.self, AgendaEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for row in FieldOptionDTO.rows(from: [
        "event": [
            "reason": ["BIRTHDAY", "BACK_IN_STOCK", "COLLECTION_LAUNCH", "VIP_EVENT", "FOLLOW_UP", "WISHLIST_AVAILABLE"],
            "meetingType": ["IN_PERSON", "VIDEO_CALL"]
        ]
    ]) {
        container.mainContext.insert(FieldOption(dto: row))
    }

    // Saving needs the session and the services, injected at the root in the app.
    return NavigationStack {
        EventComposerView(date: .now)
    }
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
    .modelContainer(container)
    .tint(Color(.Base.ink))
}

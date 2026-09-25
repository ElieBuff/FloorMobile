//
//  TaskCheckbox.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// The tick at the end of a task row: a ring while there is work left, a filled
/// mark once it is done.
///
/// A control of its own rather than a shape inside `TaskRow`, because it is the
/// one thing in a day's list that writes — and `TaskRow`, like `EventRow`, only
/// paints. The writing itself belongs to `TaskActions`, which this holds; what
/// is left here is a button and two shapes.
struct TaskCheckbox: View {
    let id: String
    let status: TaskStatus
    /// Owned by the row, not by the tick: the whole row paints the pending
    /// status, so both have to read the same one. `@Bindable` for the alert's
    /// two-way binding below.
    @Bindable var actions: TaskActions

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services

    /// The tap if one is in flight, the stored row otherwise.
    private var shown: TaskStatus { actions.shownStatus(over: status) }

    var body: some View {
        Button {
            actions.move(
                id, to: shown.toggled, stored: status,
                session: session, services: services
            )
        } label: {
            mark
                // 44 × 44 for the finger, 22 for the eye. The row trims its
                // trailing padding by the same 11 points this frame adds on
                // each side, so the ring stays exactly where it was drawn.
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(actions.isWorking)
        .animation(.smooth(duration: 0.2), value: shown)
        .onChange(of: status) { actions.settle() }
        .accessibilityLabel(String(localized: "Done"))
        .accessibilityValue(shown.displayLabel)
        .accessibilityAddTraits(shown == .completed ? [.isButton, .isSelected] : .isButton)
        .floorAlert($actions.alert)
    }

    @ViewBuilder
    private var mark: some View {
        if shown == .completed {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                // The same grey the rest of the row takes when it is done: the
                // mark settles with it rather than standing out of it.
                .foregroundStyle(Color(.OnSurface.textTertiary))
                .transition(.opacity)
        } else {
            Circle()
                .strokeBorder(Color(.Base.ink).opacity(0.25), lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .transition(.opacity)
        }
    }
}

// MARK: - Previews

#Preview("Both states") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return HStack(spacing: 24) {
        TaskCheckbox(id: "t-1", status: .toDo, actions: TaskActions())
        TaskCheckbox(id: "t-2", status: .completed, actions: TaskActions())
    }
    .padding(24)
    .background(Color(.OnCanvas.surface))
    // Tapping in this preview sends a request through the preview session,
    // which goes nowhere — the mark flips, then the failure alert arrives.
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
}

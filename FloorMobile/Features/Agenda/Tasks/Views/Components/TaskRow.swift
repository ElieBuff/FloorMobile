//
//  TaskRow.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// A single task row inside a day's tasks card: a tinted icon for the task's
/// `Reason`, the category label, the task title, the client, and the tick that
/// marks it done. Lives on its own next to `DayTasksSection`, the same way
/// `AIActionRow` sits beside `AIRecommendationsSection`.
///
/// Unlike `NextAppointmentCard`, this row has no background of its own — in
/// the Figma design every row shares one card, separated by thin dividers,
/// so the card chrome belongs to `DayTasksSection`, not to each row.
///
/// The row paints; it does not write. The tick is a `TaskCheckbox`, which owns
/// its own request — the same division of labour as `EventRow`, where
/// `DayTimeline` decides and the row draws.
///
/// ## Two targets, not one
///
/// The row is two buttons side by side rather than one button with a shape
/// inside it: the left one opens the task, the right one marks it done. A tick
/// nested in a row-wide button would be a control that cannot be pressed — the
/// row would swallow the tap and open the detail instead, which is exactly the
/// lie this row used to tell.
struct TaskRow: View {
    let task: AgendaTask
    var onTap: () -> Void = {}

    /// The writes-in-flight state the tick works through, held here rather than
    /// inside it so the *whole* row answers the tap.
    ///
    /// Reading the stored row instead meant the mark filled at once while
    /// everything else waited for the round trip and then snapped a second
    /// later: one gesture read as two events. The row is still the thing that
    /// paints and the tick is still the thing that writes — the row only needs
    /// to know what the tick is in the middle of.
    @State private var actions = TaskActions()

    /// What the row paints: the tap if one is in flight, the stored row
    /// otherwise — the same value the tick reads.
    private var shown: TaskStatus { actions.shownStatus(over: task.status) }

    /// A task that is done is still worth seeing — it is the proof the work
    /// happened — but it is no longer work, so it recedes. The same treatment
    /// `EventRow` gives an appointment the day has left behind.
    private var isDone: Bool { shown == .completed }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 14) {
                    icon
                    text
                    Spacer(minLength: 8)
                }
                // Without this the button only answers where it drew ink, and
                // the empty space next to a short title would do nothing.
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)

            TaskCheckbox(id: task.id, status: task.status, actions: actions)
        }
        .padding(.leading, 18)
        // 7, not 18: the tick's 44-point target already carries 11 points of
        // clear space on each side, and 7 + 11 lands its ring exactly where
        // the 18-point inset used to.
        .padding(.trailing, 7)
        .padding(.vertical, 12)
        // The badge and the three text colours cross-fade rather than cut, on
        // the curve and duration the tick already uses.
        .animation(.smooth(duration: 0.2), value: shown)
    }

    private var icon: some View {
        ReasonIcon(reason: task.reason)
            // The badge is the row's one block of colour; drained of it, the
            // row reads as settled without going invisible.
            .saturation(isDone ? 0 : 1)
            .opacity(isDone ? 0.5 : 1)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.reason.displayLabel)
                .eyebrow(weight: .bold, tracking: 1.2)
                // Grey rather than the reason's colour at low opacity: a tinted
                // label faded enough to read as "done" no longer passes
                // contrast, and this line is 10pt.
                .foregroundStyle(isDone ? Color(.OnSurface.textTertiary) : task.reason.fillColor)
            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(isDone ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textPrimary))
                .lineLimit(1)
            if let clientDisplayName = task.clientDisplayName {
                Text(clientDisplayName)
                    .font(.caption)
                    .foregroundStyle(isDone ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textSecondary))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Previews

/// A container for the previews: rows write their status through the session
/// and the services, injected at the root in the app.
private func previewTask(
    id: String,
    status: TaskStatus,
    reason: Reason,
    title: String
) -> AgendaTask {
    AgendaTask(
        id: id, statusRaw: status.rawValue, reasonRaw: reason.rawValue, title: title,
        startDate: .now, createdAt: .now, updatedAt: .now,
        client: ClientSummary(firstName: "Léa", lastName: "Bonnet")
    )
}

#Preview("To do, then done") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return VStack(spacing: 0) {
        TaskRow(task: previewTask(
            id: "1", status: .toDo, reason: .birthday,
            title: "Send diamond-earrings quote"
        ))
        CardDivider()
        TaskRow(task: previewTask(
            id: "2", status: .completed, reason: .followUp,
            title: "Call about the Solène order"
        ))
    }
    .background(Color(.OnCanvas.surface), in: RoundedRectangle(cornerRadius: AppRadius.large))
    .padding()
    .background(Color(.Base.canvas))
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
}

#Preview("Every reason") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return VStack(spacing: 0) {
        ForEach(Reason.allCases, id: \.self) { reason in
            TaskRow(task: previewTask(
                id: reason.rawValue, status: .toDo, reason: reason,
                title: "Example task for \(reason.displayLabel)"
            ))
            if reason != Reason.allCases.last {
                CardDivider()
            }
        }
    }
    .background(Color(.OnCanvas.surface), in: RoundedRectangle(cornerRadius: AppRadius.large))
    .padding()
    .background(Color(.Base.canvas))
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
}

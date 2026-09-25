//
//  TaskStatusSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// The three states a task can be moved to, and the control that moves it.
///
/// A section rather than a control, for the reason the other sections are
/// sections: it reaches for the session and the services itself. `TaskDetailView`
/// is otherwise a read-only screen, and keeping that out here is what lets it
/// stay one. The write itself belongs to `TaskActions`, shared with the tick in
/// a day's list.
///
/// The control is hand-rolled rather than a `Picker(.segmented)`, which is a
/// single line of text: this stacks a mark over a label, and the mark is what
/// an advisor reads at arm's length on the shop floor.
///
/// The pill moves on the tap, not on the answer. A segmented control that
/// waits for a round trip before responding reads as a broken one, so the
/// chosen cell takes the pill straight away and the request follows behind.
/// The slide *is* the acknowledgement — there is nothing else to show while the
/// server thinks. Why that is safe is `TaskActions`' story to tell.
struct TaskStatusSection: View {
    let id: String
    let status: TaskStatus

    @State private var actions = TaskActions()
    /// Lets the pill travel between cells instead of blinking out of one and
    /// into the next.
    @Namespace private var pill

    /// What the control shows: the tap if one is in flight, the stored row
    /// otherwise.
    private var shown: TaskStatus { actions.shownStatus(over: status) }

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TaskStatus.selectable, id: \.self) { candidate in
                cell(for: candidate)
            }
        }
        .padding(4)
        .background(Color(.OnSurface.surfaceFaint), in: .rect(cornerRadius: 18, style: .continuous))
        .disabled(actions.isWorking)
        // The row caught up — either with the tap, or with something else the
        // server decided.
        .onChange(of: status) { _, newValue in
            // Only a transaction when the pill actually has somewhere to go.
            // Dropping a pending value the row has caught up with changes
            // nothing on screen, and animating it restarts the slide mid-flight.
            if actions.pendingStatus == newValue {
                actions.settle()
            } else {
                _ = withAnimation(Self.slide) { actions.settle() }
            }
        }
        .floorAlert($actions.alert)
    }

    private static let slide = Animation.smooth(duration: 0.28)

    private func cell(for candidate: TaskStatus) -> some View {
        let isSelected = candidate == shown
        return Button {
            guard !isSelected else { return }
            update(to: candidate)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: candidate.symbolName)
                    .font(.title3)
                Text(candidate.displayLabel)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            // The chosen state carries the app's one accent; the others carry
            // the grey every secondary label uses. Not the mockup's 45% ink,
            // which measures 4.1:1 on white and fails AA under 18pt — which is
            // what these labels are.
            .foregroundStyle(isSelected ? Color(.Accent.now) : Color(.OnSurface.textSecondary))
            .frame(maxWidth: .infinity)
            // A floor, not a height: the cell grows with Dynamic Type rather
            // than clipping the label someone asked to enlarge.
            .frame(minHeight: 62)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.Accent.now).opacity(0.12))
                        // One pill for the whole control: it slides from the
                        // cell it was in to the one that was tapped.
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Hands the move to `TaskActions`, wrapping the two moments it paints —
    /// the optimistic slide and its rollback — so the pill travels instead of
    /// jumping.
    private func update(to candidate: TaskStatus) {
        actions.move(
            id, to: candidate, stored: status,
            session: session, services: services
        ) { change in
            withAnimation(Self.slide, change)
        }
    }
}

// MARK: - Previews

#Preview("Each state") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return VStack(spacing: 20) {
        TaskStatusSection(id: "t-1", status: .toDo)
        TaskStatusSection(id: "t-2", status: .completed)
        TaskStatusSection(id: "t-3", status: .canceled)
    }
    .padding(AppSpacing.cardInset)
    .frame(width: 361)
    .cardStyle()
    .padding(24)
    .background(Color(.Base.canvas))
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
}

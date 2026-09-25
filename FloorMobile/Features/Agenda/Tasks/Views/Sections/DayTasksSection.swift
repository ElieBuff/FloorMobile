//
//  DayTasksSection.swift
//  FloorMobile
//

import SwiftUI
import SwiftData
import os

/// The tasks for a given day (whole day: past and upcoming), rendered as a
/// single card of `TaskRow`s, or an empty card when there are none. Header-less
/// and date-driven so it can be reused wherever a day's tasks are shown — the
/// title belongs to the caller (e.g. `TodaysTasksSection`), as does the empty
/// message via `emptyMessage`. `limit` caps how many rows load; `nil` loads the
/// whole day.
///
/// Not the whole day's *tasks*, though: only those `TaskStatus.listed` admits —
/// what is left to do and what was done. A cancelled task is not work any more
/// and leaves the day entirely. `completed` decides what becomes of the done
/// ones.
struct DayTasksSection: View {
    /// What the day does with the tasks that are finished.
    enum Completed {
        /// They leave the list. Home is a to-do list, not a record.
        case hidden
        /// They stay, folded into a group that opens — the agenda is where the
        /// day is reviewed, and what was done is part of it.
        case grouped
    }

    private let completedPolicy: Completed
    private let emptyMessage: String
    /// What the empty card's button does. Empty by default, like `onSelect`:
    /// the section shows a day, it does not decide what a day without tasks
    /// leads to. Both callers open the task composer, but each through its own
    /// cover.
    private let onCreate: () -> Void
    /// What a tapped task does. Empty by default: the caller decides — both the
    /// agenda and Home open the detail on it, each in its own cover.
    private let onSelect: (AgendaTask) -> Void
    @Query private var tasks: [AgendaTask]

    /// Closed on arrival. What is done is a record, not the work: it is there
    /// to be checked, not to be read on the way past.
    @State private var showsCompleted = false

    /// Builds the query for `date`'s whole day, soonest first, optionally capped
    /// so the store never loads more than we display.
    ///
    /// Filtered on `statusRaw` rather than on `status`: the typed view is a
    /// computed property, and a `#Predicate` can only speak of what is stored.
    /// Which statuses belong in a day at all is `TaskStatus.listed`'s business;
    /// whether the done ones are among them is the caller's.
    ///
    /// `.hidden` leaves a list of what is still owed. A task ticked there does
    /// not vanish under the finger: the mark fills at once, the row holds its
    /// place through `TaskActions.grace` and the round trip — the window in
    /// which the tick can be taken back — and only then slides out. Under
    /// `.grouped` it makes the same journey, and lands in the group below
    /// rather than leaving.
    init(
        date: Date,
        limit: Int? = nil,
        completed: Completed = .grouped,
        emptyMessage: String = String(localized: "No task"),
        onCreate: @escaping () -> Void = {},
        onSelect: @escaping (AgendaTask) -> Void = { _ in }
    ) {
        self.completedPolicy = completed
        self.emptyMessage = emptyMessage
        self.onCreate = onCreate
        self.onSelect = onSelect
        let startOfDay = date.startOfDay
        let startOfNextDay = date.startOfNextDay
        let listed = TaskStatus.listed
            .filter { completed == .grouped || $0 != .completed }
            .map(\.rawValue)
        var descriptor = FetchDescriptor<AgendaTask>(
            predicate: #Predicate {
                listed.contains($0.statusRaw)
                    && $0.startDate >= startOfDay
                    && $0.startDate < startOfNextDay
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        if let limit { descriptor.fetchLimit = limit }
        _tasks = Query(descriptor)
    }

    var body: some View {
        content
            // Rows arrive through `@Query`, and a store change carries no
            // animation of its own: a ticked task would vanish and everything
            // below it would jump up within the same frame. Keyed on the row
            // ids, so the list animates when rows come and go — including the
            // swap to the empty card when the last one leaves — and not when
            // one of them merely changes status.
            .animation(.smooth(duration: 0.25), value: tasks.map(\.id))
    }

    /// Still owed, in the order the day runs.
    private var open: [AgendaTask] {
        tasks.filter { $0.status != .completed }
    }

    /// Done. Empty unless the caller asked for `.grouped`, since the query
    /// leaves them out otherwise.
    private var done: [AgendaTask] {
        tasks.filter { $0.status == .completed }
    }

    @ViewBuilder
    private var content: some View {
        if tasks.isEmpty {
            EmptySectionCard(
                icon: { Image(systemName: "checklist").foregroundStyle(Color(.OnCanvas.textPrimary)) },
                message: emptyMessage,
                action: EmptySectionAction(label: String(localized: "New Task"), systemImage: "plus", handler: onCreate)
            )
        } else {
            VStack(spacing: 0) {
                ForEach(open) { task in
                    TaskRow(task: task) { onSelect(task) }
                    if task.id != open.last?.id {
                        CardDivider()
                    }
                }

                // Nothing at all when nothing is done — no row, no rule, no
                // count. An empty group is a line that says there is nothing
                // to see, which is worse than not being there.
                if !done.isEmpty {
                    if !open.isEmpty { CardDivider() }
                    completedGroup
                }
            }
            .cardStyle()
        }
    }

    /// The done tasks, behind a row that says how many and opens them.
    ///
    /// Inside the same card as the open ones, not a card of its own: they
    /// belong to the day, and a second card would read as a second list.
    @ViewBuilder
    private var completedGroup: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { showsCompleted.toggle() }
        } label: {
            HStack(spacing: 10) {
                // The mark of the column the rows put their reason badge in —
                // smaller and mute, because this row names a group rather than
                // a task.
                Circle()
                    .fill(Color(.OnSurface.borderSubtle))
                    .frame(width: 18, height: 18)

                Text("\(done.count) task completed")
                    .font(.caption)
                    // Not the mockup's 50% ink: at 12.5pt that measures under
                    // 4.5:1 on the card, and this line is the only thing that
                    // says the group is there.
                    .foregroundStyle(Color(.OnSurface.textSecondary))

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.OnSurface.textTertiary))
                    .rotationEffect(.degrees(showsCompleted ? 180 : 0))
            }
            .padding(.horizontal, AppSpacing.cardInset)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(showsCompleted ? Text("Expanded") : Text("Collapsed"))

        if showsCompleted {
            ForEach(done) { task in
                CardDivider()
                TaskRow(task: task) { onSelect(task) }
            }
        }
    }
}

// The rows tick through the session and the services, injected at the root in
// the app — so a preview that shows one has to hand them over too. The third
// task is cancelled: it is inserted, and it does not appear.
#Preview("Populated") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let statuses = ["TO_DO", "COMPLETED", "CANCELED"]
    for (i, status) in statuses.enumerated() {
        container.mainContext.insert(AgendaTask(
            id: "0\(i)", statusRaw: status, reasonRaw: "FOLLOW_UP", title: "Task \(i + 1)",
            startDate: Date().addingTimeInterval(Double(i + 1) * 3600),
            createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Elie", lastName: "Buff")
        ))
    }
    return DayTasksSection(date: .now)
        .modelContainer(container)
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
        .padding()
        .background(Color.black)
}

#Preview("Empty") {
    let container = try! ModelContainer(
        for: AgendaTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return DayTasksSection(date: .now)
        .modelContainer(container)
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
        .padding()
        .background(Color.black)
}

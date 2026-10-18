//
//  DayLayout.swift
//  FloorMobile
//

import Foundation

/// Lays one day's events out as the ordered list the agenda draws: the rows,
/// each with the standing it should be painted in, and the current-time rule
/// put where it belongs.
///
/// No rule of its own about what an appointment *is* — that lives on
/// `AgendaEvent` (`standing(at:)`, `progress(at:)`). This only decides the
/// order and where the rule goes, from the same `now` for every row, so the
/// rule can never slide past an appointment that has not yet greyed out.
///
/// It takes `now` instead of calling `Date()`, which is what makes it testable
/// at any instant, including the exact second an appointment ends.
nonisolated enum DayLayout {

    /// Where the current-time rule crosses an appointment's row: the time it
    /// reads, and how far down the row it sits.
    ///
    /// It carries its date, unlike the standalone `.now` — and for the mirror
    /// reason. The standalone rule sits *between* two rows, so a quiet minute
    /// must not make the list compare unequal and animate a move that never
    /// happened. This one moves a point or two down the card every minute, and
    /// that slide is the whole point of it.
    struct NowRule: Equatable, Sendable {
        let date: Date
        /// 0…1 — the fraction of the appointment that has elapsed.
        let progress: Double
    }

    enum Item: Identifiable, Equatable {
        /// An appointment. `rule` is set on the one `now` falls inside, and on
        /// nothing else.
        case event(AgendaEvent, standing: AgendaEvent.Standing, rule: NowRule?)
        /// The rule on its own line, for the moments no appointment is under
        /// way. It holds no date: carrying one would make the list compare
        /// unequal on every tick and animate a move that never happened — the
        /// time it displays comes from the view's own clock.
        case now

        var id: String {
            switch self {
            case .event(let event, _, _): event.id
            case .now: "now"
            }
        }

        /// Compared by `id` rather than by object: SwiftData can hand back a
        /// different instance for the same stored row, and two such instances
        /// are the same appointment as far as the list is concerned.
        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case let (.event(left, leftStanding, leftRule), .event(right, rightStanding, rightRule)):
                left.id == right.id && leftStanding == rightStanding && leftRule == rightRule
            case (.now, .now):
                true
            default:
                false
            }
        }
    }

    /// The day's events in order, with the current-time rule placed — across
    /// the appointment under way, or on a line of its own between two of them.
    ///
    /// `day` is separate from `now` on purpose: browsing next week must not draw
    /// an "it is 11:20" rule in the middle of it. And an empty day gets no rule
    /// either — a time rule with nothing around it states the obvious and leaves
    /// the empty card looking interrupted.
    static func items(
        events: [AgendaEvent],
        now: Date,
        day: Date,
        calendar: Calendar = .current
    ) -> [Item] {
        // Sorted here rather than trusted from the caller: a pure function
        // should answer for its result whatever it is handed.
        let sorted = events.sorted { $0.startDate < $1.startDate }
        let isToday = calendar.isDate(day, inSameDayAs: now)
        // The appointment `now` falls inside — the earliest one when two
        // overlap, since the rule has one position and the day reads top-down.
        // Start included, end excluded: the same boundary `standing(at:)`
        // uses, so a slot is over for both at the same instant.
        let underway = isToday
            ? sorted.firstIndex { $0.startDate <= now && now < $0.endDate }
            : nil

        let rows = sorted.enumerated().map { index, event in
            Item.event(
                event,
                standing: event.standing(at: now),
                rule: index == underway
                    ? event.progress(at: now).map { NowRule(date: now, progress: $0) }
                    : nil
            )
        }

        // The line of its own is for the gaps: before the first appointment,
        // between two, after the last. While one is under way it carries the
        // rule itself, and a second one between two rows would state the same
        // thing twice, in a place that is not where you are.
        guard !rows.isEmpty, isToday, underway == nil else { return rows }

        // The first appointment still ahead of us — or the end of the list when
        // every one of them has already run. Nothing can have started without
        // having ended here, or it would be `underway`.
        let next = sorted.firstIndex { $0.startDate >= now } ?? rows.count
        var withRule = rows
        withRule.insert(.now, at: next)
        return withRule
    }
}

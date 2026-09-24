//
//  DayTimeline.swift
//  FloorMobile
//

import Foundation

/// Turns one day's events into the ordered list the agenda draws: the rows, each
/// with the state it should be painted in, and the current-time rule put where
/// it belongs.
///
/// All of those answers depend on the same thing — what time it is — so they are
/// produced together. Computed separately in the view, they could disagree: the
/// rule sliding past an appointment that has not yet greyed out.
///
/// It takes `now` instead of calling `Date()`, which is what makes it testable
/// at any instant, including the exact second an appointment ends.
nonisolated enum DayTimeline {

    /// How a row should read — the server's status crossed with the clock.
    ///
    /// Deliberately not the same thing as `EventStatus`: that one is what the
    /// server asserts, this one is what the advisor sees. A `.planned` booking
    /// becomes `.done` on screen when its slot elapses, without its stored
    /// status moving at all.
    enum Standing: Equatable, Sendable {
        /// Still to come, or under way. Shows its duration.
        case upcoming
        case done
        case cancelled

        /// Whether the row recedes into the background. Not a statement about
        /// time: an appointment cancelled for next week dims too. Done and
        /// cancelled look alike; they only differ in the word the card shows.
        var isDimmed: Bool { self != .upcoming }
    }

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
        case event(AgendaEvent, standing: Standing, rule: NowRule?)
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

    /// The server's word first, the clock second.
    ///
    /// Cancelled is not finished — the two recede alike but must not read alike.
    /// Completed is finished even if the slot has not elapsed, because the
    /// advisor closed it out early. For everything the server still calls open,
    /// only the clock can tell, since a booking is never moved on its own as the
    /// day goes by.
    ///
    /// On the clock, an event turns past when it **ends**, not when it starts:
    /// the appointment you are currently in would otherwise dim at exactly the
    /// moment it matters most.
    static func standing(of event: AgendaEvent, at now: Date) -> Standing {
        switch event.status {
        case .cancelled: .cancelled
        case .completed: .done
        case .planned, .confirmed, .other: event.endDate <= now ? .done : .upcoming
        }
    }

    /// The rule for an appointment under way, positioned by how much of it has
    /// elapsed. `nil` for a slot with no length at all — there is no inside to
    /// be in.
    static func nowRule(for event: AgendaEvent, at now: Date) -> NowRule? {
        let length = event.endDate.timeIntervalSince(event.startDate)
        guard length > 0 else { return nil }
        let elapsed = now.timeIntervalSince(event.startDate)
        return NowRule(date: now, progress: min(max(elapsed / length, 0), 1))
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
        // Start included, end excluded: the same boundary `standing(of:at:)`
        // uses, so a slot is over for both at the same instant.
        let underway = isToday
            ? sorted.firstIndex { $0.startDate <= now && now < $0.endDate }
            : nil

        let rows = sorted.enumerated().map { index, event in
            Item.event(
                event,
                standing: standing(of: event, at: now),
                rule: index == underway ? nowRule(for: event, at: now) : nil
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

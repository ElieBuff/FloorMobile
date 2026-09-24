//
//  CalendarExpansion.swift
//  FloorMobile
//

import CoreGraphics

/// Where the calendar card sits between the week and the month, and the
/// decisions that depend on it: how far a drag has taken it, whether letting go
/// opens or closes it, and how much of the finger's speed the spring inherits.
///
/// A value type rather than a pair of `@State` in the view, for the reason
/// `CalendarGrid` is one: this is the delicate half of the gesture — give at
/// both ends, a flick judged on where it is heading rather than where it
/// stopped, a velocity handover that has to be capped — and none of it can be
/// checked by dragging the card twice by hand. `CalendarExpansionTests` checks
/// it instead.
nonisolated struct CalendarExpansion: Equatable, Sendable {
    /// Which of the two settled states the card rests in when no finger is on
    /// it.
    var isExpanded = false

    /// Set only while a vertical drag is in flight, overriding `isExpanded`.
    /// Travels slightly outside 0…1 when the finger pulls past a limit.
    private(set) var dragProgress: CGFloat?

    /// Beyond this much travel still to cover, the handover division is safe.
    /// Released right at a limit, `remaining` is tiny and the quotient blows up,
    /// so the handover is dropped: a spring given an absurd initial velocity
    /// fires the card across the screen before coming back.
    private static let handoverFloor: CGFloat = 0.001

    /// Ceiling on the velocity handed to the spring, in animated units per
    /// second.
    private static let handoverLimit: Double = 20

    /// 0 for the week, 1 for the month, anything between while a finger is on
    /// the card — and slightly outside both while one pulls past a limit.
    var progress: CGFloat {
        dragProgress ?? (isExpanded ? 1 : 0)
    }

    /// The same, held inside the two real states.
    ///
    /// Only the card's height follows the overshoot; the grid keeps its place,
    /// so pulling past the month opens empty card below the last week instead of
    /// dragging the weeks out of their rows. That is what over-scrolling looks
    /// like everywhere else: the container gives, the content stays put.
    var settledProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    /// Records where the vertical distance the finger has travelled puts the
    /// card, measured from the state the drag started in.
    mutating func drag(by translationHeight: CGFloat) {
        let base: CGFloat = isExpanded ? 1 : 0
        dragProgress = Self.withGive(base + translationHeight / CalendarMetrics.expandDistance)
    }

    /// Whether letting go here opens the card.
    ///
    /// Judged on where the card would be a moment from now if the finger kept
    /// its speed — so a quick flick commits long before the halfway mark, the
    /// way every native sheet does, instead of snapping back because it
    /// happened to stop at 40%.
    ///
    /// - Parameter velocity: the finger's vertical speed, in progress per
    ///   second.
    func opensOnRelease(velocity: CGFloat) -> Bool {
        progress + velocity * CalendarMetrics.flickLookahead > 0.5
    }

    /// How much of the finger's speed the settling spring starts with.
    ///
    /// Without it the card opens at one fixed pace whatever the gesture, which
    /// is the clearest tell that a transition is scripted rather than physical:
    /// a hard flick and a slow pull end in exactly the same time. The value is
    /// in units of the animated value per second, hence the division by the
    /// travel still to cover.
    func handoverVelocity(toExpanded expanded: Bool, velocity: CGFloat) -> Double {
        let target: CGFloat = expanded ? 1 : 0
        let remaining = abs(target - progress)
        guard remaining > Self.handoverFloor else { return 0 }
        let handover = Double(velocity / remaining)
        return min(max(handover, -Self.handoverLimit), Self.handoverLimit)
    }

    /// Commits one of the two settled states and lets go of the drag.
    mutating func settle(toExpanded expanded: Bool) {
        isExpanded = expanded
        dragProgress = nil
    }

    /// Lets the drag travel past the two ends, against resistance.
    static func withGive(_ raw: CGFloat) -> CGFloat {
        if raw > 1 {
            return 1 + RubberBand.resist(raw - 1, give: CalendarMetrics.overExpand)
        } else if raw < 0 {
            return -RubberBand.resist(-raw, give: CalendarMetrics.overCollapse)
        }
        return raw
    }
}

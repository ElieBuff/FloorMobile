//
//  CalendarRowSettle.swift
//  FloorMobile
//

import SwiftUI

/// Lets a row arrive slightly behind its slot and settle into it, leaning toward
/// the week the card was collapsed on.
///
/// Rows further from that week start later, so the month unrolls outward from
/// the selected day rather than appearing as one rigid block. The amplitude is
/// deliberately small: the effect should be felt in the movement, not read as a
/// separate animation playing on top of the reveal.
///
/// `Animatable` for the same reason as `CalendarReveal`, but with a sharper
/// consequence: the lean is *quadratic* in progress. Animating the resulting
/// offset directly would interpolate it linearly between its two endpoints, so
/// the settle would have one shape under a finger and a different one under a
/// spring. Lifting progress into `animatableData` gives both the same curve.
struct CalendarRowSettle: ViewModifier, Animatable {
    var progress: CGFloat
    /// -1 for a row above the collapsed week, +1 below, 0 for the week itself.
    let lean: CGFloat
    /// Share of the travel this row waits out before it starts moving.
    let delay: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(y: -lean * CalendarMetrics.rowSettle * lag)
    }

    private var lag: CGFloat {
        guard delay < 1 else { return 1 }
        let advance = min(max((progress - delay) / (1 - delay), 0), 1)
        // Squared so the row eases into its slot and stops there, instead of
        // arriving at full speed and halting.
        return (1 - advance) * (1 - advance)
    }
}

extension View {
    /// Applies the settle for a row `distance` rows away from the collapsed
    /// week, `distance` being signed: negative above, positive below.
    func calendarRowSettle(distance: Int, progress: CGFloat) -> some View {
        modifier(CalendarRowSettle(
            progress: progress,
            lean: CGFloat(distance.signum()),
            delay: CGFloat(abs(distance)) * CalendarMetrics.settleDelayStep
        ))
    }
}

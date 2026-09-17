//
//  CalendarReveal.swift
//  FloorMobile
//

import SwiftUI

/// Opens and closes the calendar's rows window: it sets the height, and softens
/// the two edges the rows travel through.
///
/// The soft edges are the whole point. The window's height is almost never an
/// exact number of rows while the card is moving, so a plain clip cuts a row in
/// half along a hard line floating inside a white card — which reads as a slice,
/// not as a reveal. Fading the edges instead lets a row arrive and leave the way
/// it would under a real edge.
///
/// The fade follows `sin(π · progress)`: nothing at either end, most in the
/// middle. Both settled states therefore stay perfectly crisp — a permanently
/// feathered week would look washed out — and the softening exists only while
/// something is actually crossing an edge.
///
/// `Animatable` is not decoration here. A gradient's stops cannot be
/// interpolated, so without lifting `progress` into `animatableData` the mask
/// would snap to its final shape on the first frame of a spring and leave the
/// rows cut by a hard line for the rest of it.
struct CalendarReveal: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            // Deliberately un-clamped: this is the one thing that follows a pull
            // past either end, so the card stretches and squeezes under the
            // finger while the grid inside it holds still.
            .frame(height: CalendarMetrics.collapsedRowsHeight + CalendarMetrics.expandDistance * progress)
            .clipped()
            .mask { edgeMask }
    }

    /// Feathering is a transition effect, so it reads the settled progress: past
    /// the ends `sin` turns negative and would invert the gradient's stops.
    private var settledProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    /// The clip is what actually bounds the window — a mask alone lets the rows
    /// and the pager's neighbouring pages spill out of the frame. The mask only
    /// softens the last few points before that bound, and since it reaches zero
    /// alpha exactly at the edge, the clip never cuts anything still visible.
    private var edgeMask: some View {
        GeometryReader { proxy in
            let fade = min(
                CalendarMetrics.revealEdgeFade * sin(.pi * settledProgress) / max(proxy.size.height, 1),
                0.5
            )
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: fade),
                    .init(color: .black, location: 1 - fade),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

extension View {
    /// Shows `progress` worth of the calendar's rows, 0 being one week and 1 the
    /// whole month.
    func calendarReveal(progress: CGFloat) -> some View {
        modifier(CalendarReveal(progress: progress))
    }
}

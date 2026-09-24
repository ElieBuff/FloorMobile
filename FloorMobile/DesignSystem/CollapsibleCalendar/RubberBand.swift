//
//  RubberBand.swift
//  FloorMobile
//

import CoreGraphics

/// The resistance a gesture meets once it is pulled past what it can actually
/// move.
///
/// Every native surface does this: a scroll view at the top still follows your
/// finger, just reluctantly, and springs back when you let go. A control that
/// instead clamps dead at its limit stops feeling like matter — which is the
/// difference between a gesture that is being tracked and one that is merely
/// being read.
nonisolated enum RubberBand {
    /// How much of the pull is passed through at the very start of the overshoot.
    /// UIScrollView's own constant.
    private static let firmness: CGFloat = 0.55

    /// `d·c·L / (L + c·d)`: almost one-to-one for the first few points, then
    /// flattening so the result approaches `give` but never reaches it, however
    /// hard the pull.
    ///
    /// - Parameters:
    ///   - distance: how far past the limit the finger has travelled.
    ///   - give: the most the surface will ever yield.
    static func resist(_ distance: CGFloat, give: CGFloat) -> CGFloat {
        guard give > 0, distance > 0 else { return 0 }
        return (distance * firmness * give) / (give + firmness * distance)
    }
}

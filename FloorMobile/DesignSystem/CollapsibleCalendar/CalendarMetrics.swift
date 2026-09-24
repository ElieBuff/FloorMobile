//
//  CalendarMetrics.swift
//  FloorMobile
//

import CoreGraphics

/// Geometry of the calendar card, from the Figma frames "AGENDA — JOUR" and
/// "AGENDA — MOIS (déplié)".
///
/// The week and the month are the same grid at two heights, so both read these
/// values: a row is 40pt whether one of them shows or six do, which is what lets
/// the card interpolate between the two states instead of swapping layouts.
/// `nonisolated` like `CalendarGrid`: constants with no isolation of their own,
/// which `CalendarExpansion` reads outside the main actor.
nonisolated enum CalendarMetrics {
    /// One week: the day pill plus its activity dot.
    static let rowHeight: CGFloat = 40
    static let rowSpacing: CGFloat = 6
    /// The row of weekday initials, which never scrolls or collapses.
    static let weekdayRowHeight: CGFloat = 14
    static let columnSpacing: CGFloat = 2

    static let pillSize: CGFloat = 30
    static let dotSize: CGFloat = 5
    /// Pill to dot, inside a day cell.
    static let dotSpacing: CGFloat = 5

    static let headerHeight: CGFloat = 19
    static let headerInset: CGFloat = 6
    static let arrowSize: CGFloat = 16

    static let handleHeight: CGFloat = 8
    static let handleWidth: CGFloat = 36
    static let handleThickness: CGFloat = 4

    static let cardPaddingVertical: CGFloat = 12
    static let cardPaddingHorizontal: CGFloat = 10
    /// Between the header, the grid and the handle.
    static let sectionSpacing: CGFloat = 10

    /// Height of the rows area with one week showing.
    static let collapsedRowsHeight = rowHeight

    /// Height of the rows area with the whole month showing.
    static let expandedRowsHeight =
        CGFloat(CalendarGrid.rowCount) * rowHeight
        + CGFloat(CalendarGrid.rowCount - 1) * rowSpacing

    /// How far the finger travels to go from the week to the month. Taking it
    /// from the two heights means the grid tracks the finger one-to-one: the
    /// rows appear exactly as fast as they are pulled down.
    static let expandDistance = expandedRowsHeight - collapsedRowsHeight

    /// How deep the window's edges are feathered mid-transition. About a third
    /// of a row: enough that a row crossing an edge is never cut by a visible
    /// line, short enough that the rows it isn't crossing stay solid.
    static let revealEdgeFade: CGFloat = 14

    /// How far a row trails its slot as it is revealed, leaning toward the week
    /// the card was collapsed on.
    ///
    /// Capped below `rowSpacing` on purpose: rows lean by different amounts at
    /// any instant, so a larger value would let two of them close the 6pt gap
    /// between their slots and overlap — a settle that costs legibility is a
    /// bad trade.
    static let rowSettle: CGFloat = 5

    /// Added to a row's start per row of distance, so the month unrolls outward
    /// from the selected week instead of arriving in one block.
    static let settleDelayStep: CGFloat = 0.05

    /// How faint a month title goes once it is a full page off-centre. Same idea
    /// as FSCalendar's `headerMinimumDissolvedAlpha`.
    static let titleDissolve: CGFloat = 0.2

    /// How far ahead, in seconds, a released flick is projected when deciding
    /// whether the card should open or close.
    static let flickLookahead: CGFloat = 0.2

    /// How far past the month the card will stretch, in progress units — about
    /// 28pt. Generous, because there is only empty card behind it.
    static let overExpand: CGFloat = 0.12

    /// How far past the week it will squeeze, ≈9pt. Much tighter: the give eats
    /// into the one row still showing, and a half-cut week is not worth it.
    static let overCollapse: CGFloat = 0.04
}

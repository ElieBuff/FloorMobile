//
//  AppBorder.swift
//  FloorMobile
//

import SwiftUI

/// A hairline border, and its presets. Two roles today: a neutral outline that
/// separates a card from the background, and the brighter, lit rim of a
/// featured card. A border of a screen's own — the dashed outline of what
/// Tolby did not understand — is built where it is drawn.
///
/// Whatever draws it — a card (`.cardStyle(border:)`), a tag
/// (`.tagStyle(border:)`) — strokes it with `strokeStyle`, so one border looks
/// the same on both.
struct AppBorder {
    var color: Color
    var width: CGFloat = 1
    /// The lengths of its dashes and of the gaps between them, in turn, as
    /// `StrokeStyle` takes them; empty for a solid line.
    var dash: [CGFloat] = []

    /// The neutral outline separating a card from the background.
    static let neutral = AppBorder(color: Color(.OnCanvas.borderDefault))
    /// The bright, lit rim of a featured card (`.featuredCardStyle`).
    static let bright = AppBorder(color: Color(.Base.paper).opacity(0.9))

    /// How its line is stroked: its width, and its dashes if it has any.
    var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: width, dash: dash)
    }
}

//
//  TapTarget.swift
//  FloorMobile
//

import SwiftUI

/// Apple's 44pt minimum tap target around a control drawn smaller, without
/// moving anything: the layout keeps the size the mockup draws, and only the
/// invisible rectangle that answers taps grows, over what surrounds the
/// control — a row's inset, the space beside it.
///
/// A fixed 44pt, whatever the text size: the room a fingertip needs does not
/// grow with the text, and a target that grew around a drawn size that does
/// not would take the taps meant for what sits beside it.
///
/// ```swift
/// Image(systemName: "mic")
///     .font(.subheadline)
///     .tapTarget(drawnSize: 32)
/// ```
private struct TapTarget: ViewModifier {
    /// The size the mockup draws the control at, which the layout keeps.
    let drawnSize: CGSize

    /// Apple's minimum, in points.
    private static let target: CGFloat = 44

    func body(content: Content) -> some View {
        content
            .frame(width: Self.target, height: Self.target)
            // Before the negative padding: the shape then covers the whole
            // target, not the drawn size the padding brings the layout back to.
            .contentShape(.rect)
            .padding(.horizontal, -(Self.target - drawnSize.width) / 2)
            .padding(.vertical, -(Self.target - drawnSize.height) / 2)
    }
}

extension View {
    /// Apple's 44pt tap target around a control drawn `drawnSize` square, the
    /// layout unchanged (`TapTarget`).
    func tapTarget(drawnSize: CGFloat) -> some View {
        tapTarget(drawnSize: CGSize(width: drawnSize, height: drawnSize))
    }

    /// The same around a control drawn wider than tall, or taller than wide —
    /// a chevron in a header that is not its own height.
    func tapTarget(drawnSize: CGSize) -> some View {
        modifier(TapTarget(drawnSize: drawnSize))
    }
}

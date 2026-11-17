//
//  AmbientBackgroundModifier.swift
//  FloorMobile
//

import SwiftUI

/// Puts the app-wide `AmbientBackground` behind a screen.
///
/// One modifier covers every case uniformly:
/// - `List` / `ScrollView`: the scrollable's own background is hidden and the
///   distance it has scrolled carries the breathing shapes away with the
///   content, while the flat fill stays pinned.
/// - Static screens: `onScrollGeometryChange` never fires, the distance stays
///   at zero, and the background is simply painted behind the content.
///
/// A screen holding several scrollables only reports the first one (SwiftUI's
/// rule for `onScrollGeometryChange`): if that one scrolls sideways, the
/// shapes stay where they hang on that screen.
///
/// - Screens whose scrolling is not the page's — the few lines of words in
///   `TranscriptionView`'s box — pass `followsScroll: false`: the distance
///   stays at zero whatever scrolls, and the shapes stay still, as on a
///   static screen.
private struct AmbientBackgroundModifier: ViewModifier {
    let followsScroll: Bool

    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                guard followsScroll else { return 0 }
                // From rest, not from the content's origin: under a navigation
                // bar a scrollable at rest sits at minus its top inset.
                let travelled = geometry.contentOffset.y + geometry.contentInsets.top
                // Capped where the shapes have left the screen: past that the
                // value stops changing, and scrolling a long list no longer
                // redraws a background that has nothing left to move.
                return min(travelled, AmbientEllipse.reach(forWidth: geometry.containerSize.width))
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .background(
                AmbientBackground(scrollOffset: scrollOffset)
            )
    }
}

extension View {
    /// Applies the app's ambient background behind this screen. Apply it to
    /// the screen's outermost container — scrollable or not. `followsScroll:
    /// false` for a screen whose scroll view is not its page: the shapes stay
    /// still.
    func ambientBackground(followsScroll: Bool = true) -> some View {
        modifier(AmbientBackgroundModifier(followsScroll: followsScroll))
    }
}

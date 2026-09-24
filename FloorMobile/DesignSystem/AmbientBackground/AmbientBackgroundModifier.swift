//
//  AmbientBackgroundModifier.swift
//  FloorMobile
//

import SwiftUI

/// Puts the app-wide `AmbientBackground` behind a screen.
///
/// One modifier covers every case uniformly:
/// - `List` / `ScrollView`: the scrollable's own background is hidden and its
///   live offset drives the wash layer, while the backdrop stays pinned.
/// - Static screens: `onScrollGeometryChange` never fires, the offset stays
///   at zero, and the background is simply painted behind the content.
private struct AmbientBackgroundModifier: ViewModifier {
    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
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
    /// the screen's outermost container — scrollable or not.
    func ambientBackground() -> some View {
        modifier(AmbientBackgroundModifier())
    }
}

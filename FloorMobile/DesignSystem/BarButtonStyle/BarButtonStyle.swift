//
//  BarButtonStyle.swift
//  FloorMobile
//

import SwiftUI

extension View {
    /// The look of a button in a screen's navigation bar — Scan, Add, Lists,
    /// a close or a save, an "Edit": the mockup's text (17 pt SF Pro Text
    /// Regular, `.body`), its icons at the text's scale (`.medium`; an icon
    /// beside its title, "Lists", goes a step smaller) and the ink
    /// (`Base.ink`, #121214), which the root's would not give: the tab view
    /// tints everything in its tabs with its own (`MainTabView`).
    ///
    /// A modifier rather than a button of the app's: the control stays the
    /// system's — a `Button`, a `Menu`, a `NavigationLink`, with an icon or a
    /// title — so the bar's glass, a sheet's roles, `.disabled` and VoiceOver
    /// come from iOS. Not a `ButtonStyle`: in a bar, a custom one replaces the
    /// system's glass, and neither a `Menu` nor a `NavigationLink` takes it.
    ///
    /// ```swift
    /// ToolbarItem(placement: .topBarTrailing) {
    ///     Button { scan() } label: {
    ///         HStack { Image(systemName: "barcode.viewfinder") }
    ///     }
    ///     .accessibilityLabel(String(localized: "Scan"))
    ///     .barButtonStyle()
    /// }
    /// ```
    ///
    /// A sheet's confirmation (`.confirmationAction`: Done, Confirm, ✓) keeps
    /// the system's look: iOS 26 draws it in tinted glass, the one button it
    /// means to stand out (decision of 12/11).
    ///
    /// On iOS 26, adjacent toolbar items in the same placement share one glass
    /// background, so two `ToolbarItem`s render as a single capsule. To split
    /// them, put a `ToolbarSpacer(.fixed)` between them: one glass holds only
    /// actions of the same kind. And the bar draws a plain `Label` or icon
    /// itself, at its own size and showing the icon only, whatever its font
    /// or scale: an icon, alone or beside its title ("Lists"), is drawn as a
    /// view of its own — an `HStack` — for this look to reach it.
    func barButtonStyle() -> some View {
        self
            .font(.body)
            .imageScale(.medium)
            .tint(Color(.Base.ink))
    }
}

// MARK: - Previews

// An icon alone, an icon with its title, each in its own glass.
#Preview("In a bar") {
    NavigationStack {
        Color.clear
            .ambientBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .imageScale(.small)
                                .accessibilityHidden(true)
                            Text(verbatim: "Lists")
                        }
                    }
                    .barButtonStyle()
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: {
                        HStack { Image(systemName: "plus") }
                    }
                    .accessibilityLabel(Text(verbatim: "Add"))
                    .barButtonStyle()
                }
            }
    }
}

//
//  BottomActionStyle.swift
//  FloorMobile
//

import SwiftUI

extension View {
    /// The look of a modal screen's main action, pinned at its bottom
    /// (`.safeAreaBar(edge: .bottom)`): the mockup's ink capsule, full width
    /// at the screen's inset — "Show N clients" in "Sort & filter", "Done" in
    /// "Voice search". Not `prominent`, the one action left at the bottom when
    /// it is not the main one — "Cancel download" while a language downloads:
    /// iOS's `.bordered`, the ink faint behind it, the text in ink.
    ///
    /// An extension rather than a `ViewModifier`: a chain of the system's
    /// modifiers, with no state of its own. Not a `ButtonStyle`, as for
    /// `.barButtonStyle()`: the control stays the system's —
    /// `.borderedProminent`, its large size, its pressed and disabled looks,
    /// VoiceOver — and only its tint and its place are the app's. One place
    /// to change them for every one — a sheet or a full screen.
    ///
    /// ```swift
    /// .safeAreaBar(edge: .bottom) {
    ///     Button(String(localized: "Done")) { … }
    ///         .bottomActionStyle()
    /// }
    /// ```
    func bottomActionStyle(prominent: Bool = true) -> some View {
        Group {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .buttonSizing(.flexible)
        .tint(Color(.Base.ink))
        .padding(.horizontal, AppSpacing.screenInset)
        .padding(.bottom, 8)
    }
}

// MARK: - Previews

#Preview("Active and waiting") {
    Color.clear
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                Button {} label: {
                    Text(verbatim: "Show 42 clients")
                }
                .bottomActionStyle()
                Button {} label: {
                    Text(verbatim: "Done")
                }
                .bottomActionStyle()
                .disabled(true)
                Button {} label: {
                    Text(verbatim: "Cancel download")
                }
                .bottomActionStyle(prominent: false)
            }
        }
        .ambientBackground()
}

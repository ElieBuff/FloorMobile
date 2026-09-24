//
//  AppHeader.swift
//  FloorMobile
//

import SwiftUI

/// The header shared by most screens: the signed-in user's avatar on the
/// leading edge, and the screen's own action buttons on the trailing edge.
///
/// It is the system navigation bar, not a custom view — the Figma mockup is
/// sized to Apple's bar (44pt under the status bar, 16pt side margins, 44pt
/// round buttons), which is exactly what a transparent, title-less toolbar
/// renders on iOS 26 with Liquid Glass. Every screen inside a
/// `NavigationStack` opts in with `.appHeader { ... }` and decides its own
/// trailing buttons; a screen that shouldn't have it simply doesn't apply it.
///
/// ```swift
/// ScrollView { ... }
///     .appHeader {
///         ToolbarItem(placement: .topBarTrailing) {
///             AppHeaderButton(systemImage: "barcode.viewfinder", label: "Scan") { scan() }
///         }
///         ToolbarItem(placement: .topBarTrailing) {
///             AppHeaderButton(systemImage: "plus", label: "Add") { add() }
///         }
///     }
/// ```
/// On iOS 26, adjacent toolbar items in the same placement share one glass
/// background, so two `ToolbarItem`s render as a single capsule — not two
/// circles. To split them into separate glass circles like the mockup, put a
/// `ToolbarSpacer(.fixed)` between them (or `.sharedBackgroundVisibility(.hidden)`
/// on each).
private struct AppHeaderModifier<Trailing: ToolbarContent>: ViewModifier {
    let trailing: Trailing

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppAvatar()
                }
                // The avatar is its own circle: opt it out of the glass
                // background the bar would otherwise draw around it.
                .sharedBackgroundVisibility(.hidden)

                trailing
            }
    }
}

extension View {
    /// Installs the app header on this screen: avatar leading, the given
    /// toolbar items trailing, no title, transparent bar. Must be applied to a
    /// view inside a `NavigationStack`.
    func appHeader<Trailing: ToolbarContent>(
        @ToolbarContentBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(AppHeaderModifier(trailing: trailing()))
    }
}

/// One round icon button in the header's trailing area (Scan, Add, …). The
/// glass circle comes from the toolbar; this only supplies the glyph, its
/// ink color, and an accessibility label.
struct AppHeaderButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        .tint(Color(.Base.ink))
        .accessibilityLabel(label)
    }
}

/// The signed-in user's avatar: a 44pt circle showing their initials, since
/// `User` carries no photo yet. Reads the session from the environment so the
/// header needs no parameters for it.
struct AppAvatar: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Circle()
            .fill(Color(.OnCanvas.surface))
            .frame(width: 44, height: 44)
            .overlay {
                Text(initials)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.Base.ink))
            }
            .accessibilityLabel(String(localized: "Profile"))
    }

    private var initials: String {
        if case .authenticated(let user) = session.state {
            return user.name.initials
        }
        return ""
    }
}

// MARK: - Previews

#Preview("Header on a scrolling screen") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<12) { index in
                    Text("Row \(index)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.OnCanvas.surface), in: .rect(cornerRadius: 20))
                }
            }
            .padding()
        }
        .ambientBackground()
        .appHeader {
            ToolbarItem(placement: .topBarTrailing) {
                AppHeaderButton(systemImage: "barcode.viewfinder", label: "Scan") {}
            }
            ToolbarItem(placement: .topBarTrailing) {
                AppHeaderButton(systemImage: "plus", label: "Add") {}
            }
        }
    }
    .environment(AppSession(auth: .preview, api: .preview))
}

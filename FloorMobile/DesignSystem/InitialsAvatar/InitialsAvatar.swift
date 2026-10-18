//
//  InitialsAvatar.swift
//  FloorMobile
//

import SwiftUI

/// A round avatar showing a person's initials (`String.initials`) — the app
/// has no photos yet.
///
/// Used for the signed-in user (`AppAvatar`) and for clients alike: whoever
/// it is, it is the same circle.
struct InitialsAvatar: View {
    /// The full name, e.g. "Raphaël Van den Berg". Empty shows an empty circle.
    let name: String
    var size: CGFloat = 44
    /// What VoiceOver reads. `nil` hides the avatar from it — the right call
    /// when the name it abbreviates is written right beside it, as in a row;
    /// shown alone, as in the header, it needs one.
    var accessibilityLabel: String?

    var body: some View {
        Circle()
            .fill(Color(.OnCanvas.surface))
            .frame(width: size, height: size)
            .overlay {
                Text(name.initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.Base.ink))
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel ?? "")
            .accessibilityHidden(accessibilityLabel == nil)
    }
}

// MARK: - Previews

#Preview("Sizes and names") {
    HStack(spacing: 16) {
        InitialsAvatar(name: "Raphaël Van den Berg")
        InitialsAvatar(name: "Alice", size: 40)
        InitialsAvatar(name: "", size: 40)
    }
    .padding(24)
    .background(Color(.Base.canvas))
}

//
//  EmptySectionCard.swift
//  FloorMobile
//

import SwiftUI

/// The single action an `EmptySectionCard` can offer, grouped in one type so
/// a card either has a complete action (label + handler, optionally a leading
/// symbol) or none at all — no half-configured button.
struct EmptySectionAction {
    var label: String
    var systemImage: String? = nil
    var handler: () -> Void
}

/// The "nothing to show" card for any section that can be empty: a
/// translucent rounded card with an icon, a status message, and an optional
/// trailing action button.
///
/// Some empty states just inform ("No appointment today"), others offer one
/// specific action ("Create task"): pass an `EmptySectionAction` to show the
/// button, or leave it `nil` to omit it.
///
/// Text parameters are plain `String`s: localization is the call site's
/// responsibility, via `String(localized:)` (design-system convention).
///
/// ```swift
/// // With an action.
/// EmptySectionCard(
///     icon: { Image(systemName: "calendar") },
///     message: String(localized: "No appointment today"),
///     action: EmptySectionAction(label: String(localized: "View agenda")) {
///         openAgenda()
///     }
/// )
///
/// // With an action carrying a leading symbol on the button.
/// EmptySectionCard(
///     icon: { Image(systemName: "checklist") },
///     message: String(localized: "No task today"),
///     action: EmptySectionAction(label: String(localized: "Create task"), systemImage: "plus") {
///         createTask()
///     }
/// )
///
/// // No action at all.
/// EmptySectionCard(icon: { Image(systemName: "tray") }, message: String(localized: "Nothing to show"))
/// ```
struct EmptySectionCard<Icon: View>: View {
    @ViewBuilder var icon: () -> Icon
    let message: String
    var action: EmptySectionAction? = nil

    var body: some View {
        HStack(spacing: 14) {
            icon()
                .frame(width: 34, height: 38)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)

            Spacer(minLength: 12)

            if let action {
                Button(action: action.handler) {
                    HStack(spacing: 4) {
                        if let systemImage = action.systemImage {
                            Image(systemName: systemImage)
                        }
                        Text(action.label)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .overlay {
                    Capsule().stroke(.white.opacity(0.35), lineWidth: 1)
                }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(height: 74)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 26))
    }
}

// MARK: - Previews

#Preview("With action") {
    VStack(spacing: 16) {
        EmptySectionCard(
            icon: { Image(systemName: "calendar").foregroundStyle(.white.opacity(0.9)) },
            message: "No appointment today",
            action: EmptySectionAction(label: "View agenda") {}
        )

        EmptySectionCard(
            icon: { Image(systemName: "checklist").foregroundStyle(.white.opacity(0.9)) },
            message: "No task today",
            action: EmptySectionAction(label: "Create task", systemImage: "plus") {}
        )
    }
    .padding()
    .background(Color.black)
}

#Preview("Without action") {
    EmptySectionCard(
        icon: { Image(systemName: "tray").foregroundStyle(.white.opacity(0.9)) },
        message: "Nothing to show"
    )
    .padding()
    .background(Color.black)
}

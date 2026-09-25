//
//  AlertCard.swift
//  FloorMobile
//

import SwiftUI

/// The dialog itself: a mark, a title, a sentence, and one or two buttons.
///
/// Built out of what the app already has rather than out of `UIAlertController`
/// — `.cardStyle` for the surface and the shadow, the `Fill`/`Tint` badge from
/// the reason rows, the capsule buttons from `EmptySectionCard` and
/// `QuickActionButton`. The system alert would arrive in a different typeface
/// scale, a different radius and a different blue, and would announce itself as
/// coming from somewhere else.
///
/// Presented by `.floorAlert(_:)`, not on its own.
struct AlertCard: View {
    let alert: FloorAlert
    /// Closes the dialog. Called before the action's own handler, so a handler
    /// that pushes a screen or opens another alert is not fighting this one on
    /// its way out.
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            badge

            VStack(spacing: 6) {
                Text(alert.title)
                    .font(.headline)
                    .foregroundStyle(Color(.OnSurface.textPrimary))

                if let message = alert.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color(.OnSurface.textSecondary))
                }
            }
            .multilineTextAlignment(.center)
            // The dialog is as wide as it needs to be; the sentence wraps
            // rather than stretching the card across the screen.
            .fixedSize(horizontal: false, vertical: true)

            buttons
                .padding(.top, 2)
        }
        .padding(24)
        .frame(maxWidth: 320)
        // The shadow does the separating. `AppBorder.neutral` is white at 35%,
        // drawn for the ambient canvas, and invisible on a paper surface.
        .cardStyle(surface: Color(.Base.paper), shadow: .high)
    }

    /// The glyph on its own tinted square — the same object the reason rows
    /// wear, so a mark in this app always means "this is what kind of thing
    /// you are looking at".
    private var badge: some View {
        Image(systemName: alert.kind.symbolName)
            .font(.title2)
            .foregroundStyle(alert.kind.fill)
            .frame(width: 48, height: 48)
            .background(alert.kind.tint, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
    }

    @ViewBuilder
    private var buttons: some View {
        if let secondary = alert.secondary {
            // The way out on the left, what the dialog is steering towards on
            // the right — reading order, not alphabetical order.
            HStack(spacing: 10) {
                button(for: secondary)
                button(for: alert.primary)
            }
        } else {
            button(for: alert.primary)
        }
    }

    private func button(for action: AlertAction) -> some View {
        Button {
            onDismiss()
            action.handler()
        } label: {
            Text(action.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(action.emphasis == .prominent ? Color(.Base.paper) : Color(.OnSurface.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                // A floor, so the button grows with Dynamic Type instead of
                // clipping its own label.
                .frame(minHeight: 46)
        }
        .buttonStyle(.plain)
        .background {
            switch action.emphasis {
            case .prominent:
                Capsule().fill(Color(.Base.ink))
            case .quiet:
                // A faint fill, the way a `.bordered` button carries one. The
                // hairline tokens are 8% ink, which on white is not a boundary
                // anyone can see — and a button whose edge is invisible is not
                // one.
                Capsule().fill(Color(.OnSurface.surfaceFaint))
            }
        }
        .contentShape(.capsule)
    }
}

// MARK: - Previews

#Preview("Error, warning, success") {
    VStack(spacing: 28) {
        AlertCard(
            alert: FloorAlert(
                kind: .error,
                title: "Task not created",
                message: "The server did not answer. Nothing was saved — your task is still here.",
                primary: AlertAction(label: "Try again"),
                secondary: AlertAction(label: "Cancel", emphasis: .quiet)
            ),
            onDismiss: {}
        )

        AlertCard(
            alert: FloorAlert(
                kind: .warning,
                title: "Discard this appointment?",
                message: "What you typed will not be kept.",
                primary: AlertAction(label: "Discard"),
                secondary: AlertAction(label: "Keep editing", emphasis: .quiet)
            ),
            onDismiss: {}
        )

        AlertCard(
            alert: FloorAlert(kind: .success, title: "Appointment booked", primary: AlertAction(label: "Done")),
            onDismiss: {}
        )
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ambientBackground()
}

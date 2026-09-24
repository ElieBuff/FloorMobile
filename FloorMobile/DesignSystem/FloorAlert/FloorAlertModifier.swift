//
//  FloorAlertModifier.swift
//  FloorMobile
//

import SwiftUI

/// Puts an `AlertCard` over the screen, behind a scrim, while the bound value
/// is non-`nil`.
///
/// An overlay rather than a `.sheet`: a sheet slides up from the bottom edge
/// and is a place you go, which is the wrong gesture for a sentence that
/// interrupts you. This lands in the middle and leaves the screen it
/// interrupted visible behind it.
///
/// ```swift
/// @State private var alert: FloorAlert?
/// // …
/// .floorAlert($alert)
/// ```
struct FloorAlertModifier: ViewModifier {
    @Binding var alert: FloorAlert?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if let alert {
                    ZStack {
                        // Tapping outside closes without choosing. For a
                        // confirmation that means "no", which is the safe
                        // reading of a tap that missed both buttons.
                        Color(.Base.ink)
                            .opacity(0.28)
                            .ignoresSafeArea()
                            .onTapGesture { self.alert = nil }
                            .accessibilityHidden(true)

                        AlertCard(alert: alert) { self.alert = nil }
                            .padding(.horizontal, 32)
                    }
                    .transition(transition)
                    // VoiceOver treats the dialog as the whole screen while it
                    // is up, so nothing underneath can be swiped to by mistake.
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                }
            }
            .animation(.smooth(duration: 0.28), value: alert?.id)
    }

    private var transition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.94).combined(with: .opacity)
    }
}

extension View {
    /// Shows a `FloorAlert` over this view while `alert` holds a value.
    func floorAlert(_ alert: Binding<FloorAlert?>) -> some View {
        modifier(FloorAlertModifier(alert: alert))
    }
}

// MARK: - Previews

#Preview("Raised over a screen") {
    @Previewable @State var alert: FloorAlert? = FloorAlert(
        kind: .error,
        title: "Task not created",
        message: "The server did not answer. Nothing was saved — your task is still here.",
        primary: AlertAction(label: "Try again"),
        secondary: AlertAction(label: "Cancel", emphasis: .quiet)
    )

    return VStack(spacing: 16) {
        Button("Show the alert") {
            alert = FloorAlert(
                kind: .warning,
                title: "Discard this appointment?",
                message: "What you typed will not be kept.",
                primary: AlertAction(label: "Discard"),
                secondary: AlertAction(label: "Keep editing", emphasis: .quiet)
            )
        }
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ambientBackground()
    .floorAlert($alert)
    .tint(Color(.Base.ink))
}

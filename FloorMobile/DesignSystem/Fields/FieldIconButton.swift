//
//  FieldIconButton.swift
//  FloorMobile
//

import SwiftUI

/// A small icon button beside a field: the microphone of a free-text field,
/// the cross that empties it, the arrow that sends it. One place for what
/// they share — the symbol drawn in a 32 pt box, Apple's 44 pt tap target
/// around it (`tapTarget`), the row's own inset absorbing the difference so
/// the symbol does not move, and the plain style that keeps a tap in a list
/// row for the button alone.
///
/// The microphone is the first of them. The keyboard already carries a
/// dictation key, so it is not there to repeat it — it is there for the case
/// the keyboard cannot serve: hands full on the floor, a client in front of
/// you, a note to leave before you forget it. One tap from the field, without
/// a keyboard ever coming up.
///
/// Quiet by default: the tertiary weight, never competing with the text it
/// stands next to — unless its caller gives it a weight of its own (`color`:
/// the ink of "Sort & filter"'s microphone and arrow).
///
/// ```swift
/// FieldIconButton(systemImage: "mic", label: String(localized: "Dictate"), action: onDictate)
/// ```
struct FieldIconButton: View {
    let systemImage: String
    /// What VoiceOver says: the symbol alone says nothing.
    let label: String
    /// The symbol's text style, the size of the field's own text: a form's
    /// fields keep the default; "Sort & filter"'s sentence, in 17 pt, passes
    /// `.body` — save its send arrow, `.title`: a 33 pt disc, iOS's nearest to
    /// the mockup's 32, a point past the box (`drawnSize`), unclipped.
    var font: Font = .subheadline
    /// The symbol's color: quiet in a form; ink beside "Sort & filter"'s
    /// sentence, where speaking is one of the two ways to describe the
    /// clients wanted, as the mockup draws it (decision of 16/11).
    var color: Color = Color(.OnSurface.textTertiary)
    let action: () -> Void

    /// The symbol's box, the mockup's size for the microphone.
    static let drawnSize: CGFloat = 32

    var body: some View {
        Button(action: action) {
            // A text style, not a fixed size: at the larger accessibility sizes
            // a 13pt symbol next to 20pt copy stops reading as part of the
            // field and starts reading as a stray mark.
            Image(systemName: systemImage)
                .font(font)
                .foregroundStyle(color)
                .tapTarget(drawnSize: Self.drawnSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Previews

#Preview {
    HStack(spacing: 12) {
        FieldIconButton(systemImage: "mic", label: "Dictate") {}
        FieldIconButton(systemImage: "xmark.circle.fill", label: "Clear text") {}
        FieldIconButton(
            systemImage: "arrow.up.circle.fill", label: "Send", font: .title, color: Color(.Base.ink)
        ) {}
    }
    .padding(40)
    .background(Color(.OnCanvas.surface))
}

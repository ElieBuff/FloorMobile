//
//  FormDictateButton.swift
//  FloorMobile
//

import SwiftUI

/// The microphone beside a free-text field.
///
/// The keyboard already carries a dictation key, so this is not there to repeat
/// it — it is there for the case the keyboard cannot serve: hands full on the
/// floor, a client in front of you, a note to leave before you forget it. One
/// tap from the field, without a keyboard ever coming up.
///
/// Quiet by design: it sits at the tertiary weight and never competes with the
/// text it stands next to.
struct FormDictateButton: View {
    let action: () -> Void

    /// Apple's 44pt minimum, scaled with the text it sits beside. The row's
    /// own inset absorbs the difference with the 32pt the mockup draws, so the
    /// microphone does not move: only the invisible rectangle around it grows.
    @ScaledMetric(relativeTo: .subheadline) private var target: CGFloat = 44
    private static let drawnSize: CGFloat = 32

    var body: some View {
        Button(action: action) {
            // A text style, not a fixed size: at the larger accessibility sizes
            // a 13pt microphone next to 20pt copy stops reading as part of the
            // field and starts reading as a stray mark.
            Image(systemName: "mic")
                .font(.subheadline)
                .foregroundStyle(Color(.OnSurface.textTertiary))
                .frame(width: target, height: target)
                .padding(-(target - Self.drawnSize) / 2)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Dictate"))
    }
}

// MARK: - Previews

#Preview {
    FormDictateButton {}
        .padding(40)
        .background(Color(.OnCanvas.surface))
}

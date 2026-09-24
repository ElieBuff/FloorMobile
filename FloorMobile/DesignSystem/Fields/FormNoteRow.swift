//
//  FormNoteRow.swift
//  FloorMobile
//

import SwiftUI

/// A form line for free text that may run to several lines, and that the reader
/// wants to see in full.
///
/// No label: the prompt names the field until there is something in it, which is
/// how Reminders treats its notes. What sits at the bottom is the dictation
/// button, when there is one.
///
/// It reserves its height instead of growing into it: a note area that starts
/// one line tall and pushes the card open as you type makes the whole screen
/// jump at every return. Reserving the room up front also says, before a word is
/// written, that this field expects more than a few.
///
/// That reserved room is the reason the row owns its field. Most of this card is
/// empty space, and every point of it has to put the caret in the note — a field
/// passed in from outside could only be tapped where its own text is drawn,
/// leaving 150 points of card that look writable and are not.
struct FormNoteRow: View {
    @Binding var text: String
    /// The greyed example shown while the field is empty.
    var prompt: String = ""
    /// A floor — a long note is shown whole rather than scrolled inside a box,
    /// which is the point of the field.
    var minHeight: CGFloat = 168
    /// Shows a dictation button under the text when set.
    var onDictate: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(prompt, text: $text, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .focused($isFocused)

            Spacer(minLength: 0)

            // Bottom right, where a composition field puts its send. Up at the
            // top right it would sit on a different axis from text that starts
            // at the top left and runs down — two marks that never line up,
            // with an empty middle between them. Down here it closes the card.
            if let onDictate {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    FormDictateButton(action: onDictate)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, AppSpacing.cardInset)
        .padding(.vertical, 16)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}

// MARK: - Previews

#Preview("Written and empty") {
    @Previewable @State var note = """
        She was torn between the 38 and the 40. Have both sizes ready in the \
        fitting room — and pull the matching belt in tan.
        """
    @Previewable @State var empty = ""

    return VStack(spacing: 24) {
        FormNoteRow(text: $note, onDictate: {})
            .frame(width: 361)
            .cardStyle()

        FormNoteRow(text: $empty, prompt: "Notes", onDictate: {})
            .frame(width: 361)
            .cardStyle()
    }
    .padding(24)
    .background(Color(.Base.canvas))
}

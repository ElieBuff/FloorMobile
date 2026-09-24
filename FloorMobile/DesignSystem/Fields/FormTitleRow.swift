//
//  FormTitleRow.swift
//  FloorMobile
//

import SwiftUI

/// The one field a form is really about: its label on the left, and the text
/// being written on the line below, larger than everything under it.
///
/// It is the only row in the card that breaks the label-left / value-right
/// arrangement, and the break is the point. A sentence — "Call about the Solène
/// order" — cannot live in the right-hand half of a row: squeezed there it wraps
/// into a narrow column or truncates, and it is the field the confirm button
/// depends on. Given its own line it gets the full width, and its size says
/// which field matters before a word is read.
///
/// No placeholder under the label, and that is the trade the label bought. An
/// example — "Autumn fitting" — set at the field's own `title3` reads as a value
/// already entered rather than as an invitation, and naming the field twice was
/// the reason the placeholder existed in the first place. The label names it;
/// the line below is left empty for the sentence being written.
///
/// It owns its text field rather than taking one, so that tapping **anywhere**
/// on the row puts the caret in it. Handed a field from outside, the row could
/// only offer the few points the text itself covers — which on an empty field is
/// nothing at all.
struct FormTitleRow: View {
    let label: String
    @Binding var text: String
    /// Shows a dictation button beside the field when set.
    var onDictate: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            FieldLabel(label)

            HStack(spacing: 9) {
                TextField("", text: $text, axis: .vertical)
                    .font(.title3)
                    .foregroundStyle(Color(.OnSurface.textPrimary))
                    .focused($isFocused)

                if let onDictate {
                    FormDictateButton(action: onDictate)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.cardInset)
        .padding(.vertical, 12)
        .frame(minHeight: 76, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}

// MARK: - Previews

#Preview("Written and empty") {
    @Previewable @State var title = "Call about the Solène order"
    @Previewable @State var empty = ""

    return VStack(spacing: 0) {
        FormTitleRow(label: "Title", text: $title, onDictate: {})
        CardDivider()
        FormTitleRow(label: "Title", text: $empty, onDictate: {})
    }
    .frame(width: 361)
    .cardStyle()
    .padding(24)
    .background(Color(.Base.canvas))
}

//
//  FormPushRow.swift
//  FloorMobile
//

import SwiftUI

/// A form line whose value is chosen on a screen of its own.
///
/// A `NavigationLink` carrying a `LabeledContent`, which is the whole
/// implementation and the whole point. The chevron, the tap target that covers
/// the band rather than the glyph, the push and the back gesture, the "Back"
/// title on the screen it opens, the VoiceOver announcement that says a button
/// leads somewhere: a link inside a list brings all of it. Anything this type
/// added on top could only take one of them away.
///
/// Reserved for sets too large for a menu; a handful of values belongs in a
/// `Picker`, which opens in place instead of taking the reader somewhere else.
///
/// ```swift
/// FormPushRow(label: "Reason", value: draft.reason.displayLabel) {
///     ReasonPickerView(selection: $draft.reason)
/// }
/// .listRowInsets(.cardRow)
/// ```
struct FormPushRow<Destination: View>: View {
    let label: String
    /// The chosen value, or an empty string when nothing is chosen yet.
    let value: String
    /// Shown, in a lighter tone, while `value` is empty.
    var placeholder: String = ""
    @ViewBuilder var destination: () -> Destination

    private var isUnset: Bool { value.isEmpty }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            LabeledContent {
                // A chosen value carries the row's ink, like every other value;
                // only an empty one steps back, so an invitation never reads as
                // an answer.
                // One line, truncated: a value here names something chosen
                // elsewhere, and "Marie-Christine de La Rochefoucauld" wrapping
                // into the right-hand half would make this row twice the height
                // of the ones around it to say what the picker already said.
                Text(isUnset ? placeholder : value)
                    .foregroundStyle(isUnset ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textPrimary))
                    .lineLimit(1)
            } label: {
                FieldLabel(label)
            }
        }
    }
}

// MARK: - Previews

#Preview("Chosen and not") {
    NavigationStack {
        List {
            Section {
                FormPushRow(label: "Reason", value: "Follow-up") {
                    Text(verbatim: "Reason picker")
                }
                .listRowInsets(.cardRow)

                FormPushRow(label: "Client", value: "", placeholder: "Choose a client") {
                    Text(verbatim: "Client picker")
                }
                .listRowInsets(.cardRow)
            }
        }
        .listStyle(.insetGrouped)
        .listRowBackground(Color(.OnCanvas.surface))
        .scrollContentBackground(.hidden)
        .ambientBackground()
    }
    .tint(Color(.Base.ink))
}

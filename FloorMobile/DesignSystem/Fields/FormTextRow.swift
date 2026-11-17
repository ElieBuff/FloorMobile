//
//  FormTextRow.swift
//  FloorMobile
//

import SwiftUI

/// A short field of a form, on one line: its label on the left, the text on
/// the right — a name, an email, a line of an address. Where `FormTitleRow`
/// gives the one sentence a form is about its own line, these are the many
/// fields that fit beside their label.
///
/// It owns its text field so that a tap anywhere on the row puts the caret in
/// it, not only on the few points an empty field covers. The keyboard is the
/// caller's: `.keyboardType(.emailAddress)`, `.textContentType(.givenName)`
/// on the row reach the field inside. The insets too, as for any row a list
/// draws: `.listRowInsets(.insetGroupedRowInsets)`.
///
/// ```swift
/// FormTextRow(label: String(localized: "Email"), text: $client.primaryEmail.replacingNil(with: ""))
///     .keyboardType(.emailAddress)
/// ```
struct FormTextRow: View {
    let label: String
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent {
            TextField("", text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .focused($isFocused)
                .accessibilityLabel(label)
        } label: {
            FieldLabel(label)
        }
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}

// MARK: - Previews

#Preview("Filled and empty") {
    @Previewable @State var firstName = "Alice"
    @Previewable @State var email = ""

    List {
        Section {
            FormTextRow(label: "First name", text: $firstName)
                .listRowInsets(.insetGroupedRowInsets)
            FormTextRow(label: "Email", text: $email)
                .keyboardType(.emailAddress)
                .listRowInsets(.insetGroupedRowInsets)
        }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color(.Base.canvas))
}

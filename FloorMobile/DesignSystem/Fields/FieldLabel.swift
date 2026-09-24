//
//  FieldLabel.swift
//  FloorMobile
//

import SwiftUI

/// The name of a field, styled the way every field in the app names itself —
/// in a composer where it is being filled, and on a detail where it is being
/// read.
///
/// Rows are built on `List`, so the row itself — its height, its insets, its
/// separator, its tap target, the chevron and the menu that hang off it — is
/// the list's business, and a row type of the app's own could only take those
/// away. The *label* is the one thing the system has no opinion on, so it is
/// the one thing this says:
///
/// ```swift
/// DatePicker(selection: $start) { FieldLabel("Start") }
/// DetailRow(label: "Start", value: start.formatted())
/// ```
///
/// Smaller and grey, where a Settings row would be black. The two read in
/// opposite directions: in Settings you are scanning for a row you already
/// filled, so the label leads; here the value is what you came for, whether to
/// type it or to check it.
struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color(.OnSurface.textSecondary))
    }
}

/// The inset every row in a card shares.
///
/// `FormTitleRow` and `FormNoteRow` draw themselves edge to edge and bring
/// their own `AppSpacing.cardInset`, because a tap anywhere on them has to
/// reach their text field. Everything else — a `Picker`, a `DatePicker`, a
/// `DetailRow` — is laid out by the list and sits at its default without this.
/// Same token, so both start on the same vertical line.
extension EdgeInsets {
    static let cardRow = EdgeInsets(
        top: 12,
        leading: AppSpacing.cardInset,
        bottom: 12,
        trailing: AppSpacing.cardInset
    )
}

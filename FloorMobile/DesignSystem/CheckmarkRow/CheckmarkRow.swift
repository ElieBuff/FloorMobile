//
//  CheckmarkRow.swift
//  FloorMobile
//

import SwiftUI

/// A list row that picks something, with a tick on its trailing edge once it
/// is picked: the whole row is the button, its label whatever the caller
/// draws (a reason's icon and name), in the rows' text style.
///
/// The tick, not a tint on the row: a row's content may own a colour (a
/// reason's), and a selected-row fill would fight it. The row of the lists
/// that pick — "Reason" (`ReasonPickerView`). Not the system's inline
/// `Picker`: it neither lets go of a pick nor takes several.
///
/// ```swift
/// CheckmarkRow(isChecked: reason == selection) {
///     pick(reason)
/// } label: {
///     Text(reason.title)
/// }
/// ```
struct CheckmarkRow<Label: View>: View {
    let isChecked: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                label()
                    .foregroundStyle(Color(.OnSurface.textPrimary))
                Spacer(minLength: 12)
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.Base.ink))
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: 36)
            // The row's insets inside the button, not around it: with `.plain`,
            // a list row's insets belong to the list, which does nothing with a
            // tap there, so a tap near an edge of the row would pick nothing.
            .padding(.insetGroupedRowInsets)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .accessibilityAddTraits(isChecked ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var picked: Set<String> = ["VIP"]

    List {
        ForEach(["VIC", "VIP", "Repeater"], id: \.self) { segment in
            CheckmarkRow(isChecked: picked.contains(segment)) {
                if picked.contains(segment) {
                    picked.remove(segment)
                } else {
                    picked.insert(segment)
                }
            } label: {
                Text(verbatim: segment)
            }
        }
    }
    .insetGroupedList()
    .ambientBackground()
}

//
//  CheckmarkRow.swift
//  FloorMobile
//

import SwiftUI

/// A list row that picks something, with a tick on its trailing edge once it
/// is picked: the whole row is the button, its label whatever the caller
/// draws (a reason's icon and name, a filter value's title), in the rows'
/// text style, and before the tick what the caller adds there, if anything
/// (`accessory`: a filter value's day, or the chevron to its calendar).
///
/// The tick, not a tint on the row: a row's content may own a colour (a
/// reason's), and a selected-row fill would fight it. One row for the lists
/// that pick — "Reason", "Filter" — so they read alike and cannot drift
/// apart. Not the system's inline `Picker`, which "Sort by" uses: it neither
/// lets go of a pick nor takes several.
///
/// ```swift
/// CheckmarkRow(isChecked: draft.isPicked(value)) {
///     toggle(value)
/// } label: {
///     Text(value.title)
/// }
/// ```
struct CheckmarkRow<Label: View, Accessory: View>: View {
    let isChecked: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    /// Between the row's spacer and the tick, on the trailing edge while
    /// nothing is ticked. A place of its own: a spacer inside the label would
    /// share the row with this one, and stop halfway.
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                label()
                    .foregroundStyle(Color(.OnSurface.textPrimary))
                Spacer(minLength: 12)
                accessory()
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
            .padding(.cardRow)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .accessibilityAddTraits(isChecked ? [.isButton, .isSelected] : .isButton)
    }
}

extension CheckmarkRow where Accessory == EmptyView {
    /// A row with nothing before its tick.
    init(isChecked: Bool, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.init(isChecked: isChecked, action: action, label: label, accessory: { EmptyView() })
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
        // A value that asks for a day, once picked: its day before the tick.
        CheckmarkRow(isChecked: true) {} label: {
            Text(verbatim: "Since a date")
        } accessory: {
            Text(verbatim: "1 Jul 2026")
                .foregroundStyle(Color(.OnSurface.textSecondary))
        }
    }
    .cardList()
    .ambientBackground()
}

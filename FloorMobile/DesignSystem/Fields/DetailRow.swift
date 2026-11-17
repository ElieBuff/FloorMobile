//
//  DetailRow.swift
//  FloorMobile
//

import SwiftUI

/// A read-only row: the field's name on the left, what it holds on the right.
///
/// The counterpart of the composer's rows, and deliberately their twin — same
/// `FieldLabel`, same `.body` value, same `.insetGroupedRowInsets` inset. The two screens show
/// the same client and the same date, one after the other, and "Edit" should
/// change what you can do with them, not where they sit.
///
/// Nothing here is tappable, so unlike `FormTitleRow` the row brings no padding
/// of its own: the list's `.insetGroupedRowInsets` is the only inset, and there is no tap
/// target to widen.
///
/// ```swift
/// Section {
///     DetailRow(label: String(localized: "Client"), value: name)
///         .listRowInsets(.insetGroupedRowInsets)
/// }
/// ```
///
/// A missing value is the caller's call, not this type's: "—" says the field is
/// empty, omitting the row says the field does not apply, and only the caller
/// knows which is true.
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                // Values here are read, not scanned: a long client name or a
                // spelled-out date wraps rather than being cut.
                .multilineTextAlignment(.trailing)
        } label: {
            FieldLabel(label)
        }
    }
}

// MARK: - Previews

#Preview("A card of read-only rows") {
    NavigationStack {
        List {
            Section {
                DetailRow(label: "Client", value: "Salomé Kaliny")
                    .listRowInsets(.insetGroupedRowInsets)
                DetailRow(label: "Start", value: "Sep 7, 2026 at 2:00 PM")
                    .listRowInsets(.insetGroupedRowInsets)
                DetailRow(label: "Duration", value: "1 h")
                    .listRowInsets(.insetGroupedRowInsets)
                DetailRow(label: "Reminder", value: "30 min before")
                    .listRowInsets(.insetGroupedRowInsets)
            }
        }
        .listStyle(.insetGrouped)
        .listRowBackground(Color(.OnCanvas.surface))
        .listRowSeparatorTint(Color(.OnSurface.borderSubtle))
        .scrollContentBackground(.hidden)
        .ambientBackground()
        .navigationTitle(Text(verbatim: "Event"))
        .navigationBarTitleDisplayMode(.inline)
    }
    .tint(Color(.Base.ink))
}

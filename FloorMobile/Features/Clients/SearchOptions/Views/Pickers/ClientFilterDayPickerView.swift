//
//  ClientFilterDayPickerView.swift
//  FloorMobile
//

import SwiftUI

/// The day a filter value asks for — "Since a date" — pushed from "Filter"
/// (`ClientFilterPickerView`) inside its sheet: a calendar that ends today,
/// opened on today, titled with the filter's name.
///
/// Touching a day only selects it; the confirmation picks the day shown and
/// goes back, today included — a `DatePicker` always holds a day, so touching
/// the one it opened on would change nothing, and today could never be
/// picked. Going back without confirming picks nothing.
///
/// Hands the day back (`onPick`) rather than writing it: the draft is the
/// sheet's, which picks the day into it.
struct ClientFilterDayPickerView: View {
    let title: LocalizedStringResource
    let onPick: (Date) -> Void

    @State private var day = Date.now
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            DatePicker(selection: $day, in: ...Date.now, displayedComponents: .date) {
                Text(title)
            }
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
        .cardList()
        .ambientBackground()
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onPick(day)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel(String(localized: "Choose this day"))
            }
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        ClientFilterDayPickerView(title: "client.filter.lastPurchase") { _ in }
    }
}

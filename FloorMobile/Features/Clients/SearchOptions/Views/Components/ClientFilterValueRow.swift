//
//  ClientFilterValueRow.swift
//  FloorMobile
//

import SwiftUI

/// A value of one of the tenant's filters, in "Filter"
/// (`ClientFilterPickerView`): ticked while the draft holds it
/// (`CheckmarkRow`). A value that asks for a day — "Since a date" — ends on
/// the day picked, or on the chevron that says a tap opens the calendar.
struct ClientFilterValueRow: View {
    let value: ClientFilterValue
    let isPicked: Bool
    /// The day picked for the value, while it asks for one and is picked.
    let day: Date?
    let action: () -> Void

    var body: some View {
        CheckmarkRow(isChecked: isPicked, action: action) {
            Text(value.title)
        } accessory: {
            if value.dateParameter != nil {
                dayAccessory
            }
        }
    }

    /// The day picked, or the chevron.
    @ViewBuilder
    private var dayAccessory: some View {
        if let day {
            Text(day.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(Color(.OnSurface.textSecondary))
        } else {
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .accessibilityHidden(true)
        }
    }
}

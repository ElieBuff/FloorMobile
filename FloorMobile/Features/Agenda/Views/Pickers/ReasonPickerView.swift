//
//  ReasonPickerView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// Why a task or an appointment exists, picked from what the server allows for
/// *that* entity.
///
/// The list comes from the stored vocabulary rather than from `Reason.allCases`,
/// and the entity is a parameter, because the server's vocabulary (`GET setup`)
/// answers per entity: today
/// `task.reason` and `event.reason` happen to hold the same six values, and
/// nothing says they will tomorrow. Ordering is the server's too — the payload's
/// order is a product decision, not an alphabetical accident.
///
/// A pushed list rather than a menu: each reason carries an icon and a colour
/// that the row it ends up on will show, and a menu would strip both back to a
/// line of text — the advisor would be choosing blind and recognising the result
/// afterwards. Six is also past the point where a menu stops being a glance.
///
/// Picking dismisses. A screen whose only job is one choice has nothing left to
/// do once it is made, and asking for a second tap on "Done" would only say so.
struct ReasonPickerView: View {
    @Binding var selection: Reason?

    @Query private var options: [EnumValue]
    @Environment(\.dismiss) private var dismiss

    private var reasons: [Reason] {
        options.resolved(fallback: Reason.selectable)
    }

    init(selection: Binding<Reason?>, key: EnumValue.Key) {
        _selection = selection
        _options = Query(EnumValue.descriptor(for: key))
    }

    var body: some View {
        List {
            Section {
                ForEach(reasons, id: \.self) { reason in
                    row(for: reason)
                }
            }
        }
        .cardList()
        .ambientBackground()
        .navigationTitle(Text("Reason"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for reason: Reason) -> some View {
        CheckmarkRow(isChecked: reason == selection) {
            selection = reason
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ReasonIcon(reason: reason)
                Text(reason.displayLabel)
            }
        }
    }
}

// MARK: - Previews

#Preview("From the server's vocabulary") {
    @Previewable @State var reason: Reason? = .followUp

    let container = try! ModelContainer(
        for: EnumValue.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    // Three of the six, out of alphabetical order, to show that the list and
    // its ordering are the payload's and not the enum's.
    for row in EnumsWire.rows(from: [
        "event": ["reason": ["VIP_EVENT", "BIRTHDAY", "FOLLOW_UP"]]
    ]) {
        container.mainContext.insert(EnumValue(wire: row))
    }

    return NavigationStack {
        ReasonPickerView(selection: $reason, key: .eventReason)
    }
    .modelContainer(container)
    .tint(Color(.Base.ink))
}

#Preview("Empty store — the local fallback") {
    // Nothing chosen: the state a new draft opens on, and the one where the
    // list shows no tick at all.
    @Previewable @State var reason: Reason? = nil

    return NavigationStack {
        ReasonPickerView(selection: $reason, key: .taskReason)
    }
    .modelContainer(for: EnumValue.self, inMemory: true)
    .tint(Color(.Base.ink))
}

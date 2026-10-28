//
//  ClientSortPickerView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "Sort by" for "My Clients", opened from `ClientSearchControls` as a sheet
/// at half height and closed with a swipe down: the tenant's sorts
/// (`ClientSort`) in the server's order, their title only, the one the search
/// runs ticked. A tap picks one into `options` — which starts the search over
/// — and closes the sheet.
///
/// The system's inline `Picker`, in the app's list style: it draws the tick
/// and tells VoiceOver which sort is picked.
struct ClientSortPickerView: View {
    @Binding var options: ClientSearchOptions

    @Query(sort: \ClientSort.rank) private var sorts: [ClientSort]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sorts.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No sorts yet"),
                        systemImage: "arrow.up.arrow.down"
                    )
                } else {
                    List {
                        Picker(String(localized: "Sort by"), selection: selection) {
                            ForEach(sorts) { sort in
                                Text(sort.title).tag(Optional(sort.value))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    .cardList()
                }
            }
            .ambientBackground()
            .navigationTitle(Text("Sort by"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// The bridge between the `Picker`, which speaks in row tags, and
    /// `options`, which keep a sort's value and its direction. A row is tagged
    /// with its sort's `value`, unique among the sorts (`@Attribute(.unique)`),
    /// so the tag finds the stored sort back. Reading ticks the sort
    /// `ClientSearchOptions.isPicked` names — its value and its direction —
    /// and none, `nil`, when none matches; writing picks the tapped sort
    /// through `ClientSearchOptions.pick`, its value and its stored direction,
    /// then closes the sheet.
    private var selection: Binding<String?> {
        Binding {
            sorts.first(where: options.isPicked)?.value
        } set: { value in
            guard let sort = sorts.first(where: { $0.value == value }) else { return }
            options.pick(sort)
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview(traits: .searchOptionsSampleData) {
    @Previewable @State var options = ClientSearchOptions()

    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientSortPickerView(options: $options)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}

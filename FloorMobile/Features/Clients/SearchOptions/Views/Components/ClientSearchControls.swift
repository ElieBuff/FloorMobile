//
//  ClientSearchControls.swift
//  FloorMobile
//

import SwiftUI

/// "Sort by" and "Filter" over "My Clients": each opens its sheet at half
/// height, closed with a swipe down.
///
/// The picks themselves live in `MyClientsList`, which sends them with the
/// search. "Sort by" sets the sort through this binding; "Filter" sets the
/// filters the same way, on "Apply", counting in the list's `scope`; its
/// button says how many values are applied.
struct ClientSearchControls: View {
    @Binding var options: ClientSearchOptions
    /// Whose clients the list shows: what "Filter" counts in.
    let scope: ClientSearchScope

    @State private var presentedSheet: Sheet?

    /// "Filter", and how many values are applied — until the applied filters
    /// show as pills above the list.
    private var filterTitle: String {
        options.filters.isEmpty ? String(localized: "Filter") : String(localized: "Filter (\(options.filters.count))")
    }

    /// The sheet open over the list.
    private enum Sheet: Identifiable {
        case sort
        case filter

        var id: Self { self }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                presentedSheet = .sort
            } label: {
                Label(String(localized: "Sort by"), systemImage: "arrow.up.arrow.down")
            }
            Button {
                presentedSheet = .filter
            } label: {
                Label(filterTitle, systemImage: "line.3.horizontal.decrease")
            }
            Spacer(minLength: 0)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(Color(.Base.ink))
        .sheet(item: $presentedSheet) { sheet in
            Group {
                switch sheet {
                case .sort: ClientSortPickerView(options: $options)
                case .filter: ClientFilterPickerView(options: $options, scope: scope)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Previews

// "Sort by" and "Filter" read the stored sorts and filters.
#Preview(traits: .searchOptionsSampleData) {
    @Previewable @State var options = ClientSearchOptions()

    ClientSearchControls(options: $options, scope: .mine)
        .padding()
}

//
//  ClientSearchControls.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "Sort by" and "Filter" over "My Clients": each opens its sheet at half
/// height, closed with a swipe down.
///
/// The picks themselves live in `MyClientsList`, which sends them with the
/// search. "Sort by" sets the sort through this binding; "Filter" will set the
/// filters the same way once it lists them.
struct ClientSearchControls: View {
    @Binding var options: ClientSearchOptions

    @State private var presentedSheet: Sheet?

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
                Label(String(localized: "Filter"), systemImage: "line.3.horizontal.decrease")
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
                case .filter: ClientFilterPickerView()
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    /// The sheet open over the list.
    private enum Sheet: Identifiable {
        case sort
        case filter

        var id: Self { self }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var options = ClientSearchOptions()

    ClientSearchControls(options: $options)
        .padding()
        // "Sort by" reads the stored sorts.
        .modelContainer(ClientSort.previewContainer())
}

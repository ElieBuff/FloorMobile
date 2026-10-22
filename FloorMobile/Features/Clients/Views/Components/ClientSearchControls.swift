//
//  ClientSearchControls.swift
//  FloorMobile
//

import SwiftUI

/// "Sort by" and "Filter" over "My Clients": each opens its sheet at half
/// height, closed with a swipe down.
///
/// The picks themselves live in `MyClientsList`, which sends them with the
/// search; the sheets will set them through these bindings once they list the
/// tenant's sorts and filters.
struct ClientSearchControls: View {
    @Binding var sortBy: String?
    @Binding var direction: ClientSearchOptions.SortDirection?
    @Binding var filterRefs: [String]

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
                case .sort: ClientSortSheet()
                case .filter: ClientFilterSheet()
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
    @Previewable @State var sortBy: String?
    @Previewable @State var direction: ClientSearchOptions.SortDirection?
    @Previewable @State var filterRefs: [String] = []

    ClientSearchControls(sortBy: $sortBy, direction: $direction, filterRefs: $filterRefs)
        .padding()
}

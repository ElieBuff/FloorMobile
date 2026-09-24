//
//  SearchView.swift
//  FloorMobile
//

import SwiftUI

/// Destination for the system search tab (`Tab(role: .search)` in
/// `MainTabView`). The search field, its transition, and the cancel button
/// all come from `.searchable()` and the search role — free, standard iOS
/// mechanics. What to search and how to lay out results is still to design;
/// for now this only shows an empty state.
struct SearchView: View {
    @State private var query = ""

    var body: some View {
        ContentUnavailableView(
            String(localized: "Search"),
            systemImage: "magnifyingglass",
            description: Text("Coming soon")
        )
        .searchable(text: $query)
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}

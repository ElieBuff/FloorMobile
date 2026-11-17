//
//  SearchView.swift
//  FloorMobile
//

import SwiftUI

/// Destination for the system search tab (`Tab(role: .search)` in
/// `MainTabView`). The search field, above the keyboard as soon as the tab
/// is selected, its transition and its close button all come from
/// `.searchable()`, the search role and the tab view's search activation —
/// free, standard iOS mechanics. What to search and how to lay out results is still to design;
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

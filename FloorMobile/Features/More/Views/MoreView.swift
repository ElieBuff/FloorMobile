//
//  MoreView.swift
//  FloorMobile
//

import SwiftUI

/// Placeholder for the "More" tab.
struct MoreView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "More"),
            systemImage: "square.grid.2x2",
            description: Text("Coming soon")
        )
        .navigationTitle(String(localized: "More"))
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
}

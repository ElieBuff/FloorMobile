//
//  MessagesView.swift
//  FloorMobile
//

import SwiftUI

/// Placeholder for the "Messages" tab.
struct MessagesView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "Messages"),
            systemImage: "message",
            description: Text("Coming soon")
        )
        .navigationTitle(String(localized: "Messages"))
    }
}

#Preview {
    NavigationStack {
        MessagesView()
    }
}

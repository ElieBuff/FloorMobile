//
//  AgentView.swift
//  FloorMobile
//

import SwiftUI

/// Placeholder for the "Agent" tab (the AI assistant).
struct AgentView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "Agent"),
            systemImage: "sparkles",
            description: Text("Coming soon")
        )
        .navigationTitle(String(localized: "Agent"))
    }
}

#Preview {
    NavigationStack {
        AgentView()
    }
}

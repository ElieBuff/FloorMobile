//
//  ProfileTimelineSection.swift
//  FloorMobile
//

import SwiftUI

/// What happened with the client, latest first — visits, messages, purchases —,
/// in the profile's "Activity" tab. Named after the server's `timeline`. A
/// placeholder until the page shows the timeline's past lines
/// (`ClientProfile.timeline`).
struct ProfileTimelineSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Recent activity")
        }
    }
}

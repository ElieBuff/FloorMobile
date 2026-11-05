//
//  ProfileSummarySection.swift
//  FloorMobile
//

import SwiftUI

/// Who the client is in a few lines, and the next step advised with them, at
/// the top of the profile's "Profile" tab. A placeholder until the page shows
/// the profile's AI summary (`ClientProfile.summary`).
struct ProfileSummarySection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Summary")
        }
    }
}

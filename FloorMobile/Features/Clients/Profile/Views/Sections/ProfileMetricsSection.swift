//
//  ProfileMetricsSection.swift
//  FloorMobile
//

import SwiftUI

/// The client's key figures — what they spend, how often they come —, at the
/// top of the profile's "Activity" tab. Named after the server's `metrics`. A
/// placeholder until `ClientProfile` carries them.
struct ProfileMetricsSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Key figures")
        }
    }
}

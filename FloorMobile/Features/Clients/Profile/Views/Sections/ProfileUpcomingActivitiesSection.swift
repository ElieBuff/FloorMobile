//
//  ProfileUpcomingActivitiesSection.swift
//  FloorMobile
//

import SwiftUI

/// What is planned with the client — appointments, tasks —, in the profile's
/// "Activity" tab. A placeholder until the page shows the timeline's upcoming
/// lines (`ClientProfile.timeline`).
struct ProfileUpcomingActivitiesSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Upcoming")
        }
    }
}

//
//  ProfilePreferencesSection.swift
//  FloorMobile
//

import SwiftUI

/// What the client likes — styles, sizes, how to be reached —, in the
/// profile's "Profile" tab. A placeholder until `ClientProfile` carries it.
struct ProfilePreferencesSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Preferences")
        }
    }
}

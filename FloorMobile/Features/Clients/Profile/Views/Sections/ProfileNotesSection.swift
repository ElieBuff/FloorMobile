//
//  ProfileNotesSection.swift
//  FloorMobile
//

import SwiftUI

/// The notes written about the client, in the profile's "Profile" tab. A
/// placeholder until `ClientProfile` carries them.
struct ProfileNotesSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Notes")
        }
    }
}

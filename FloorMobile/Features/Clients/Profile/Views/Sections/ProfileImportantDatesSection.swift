//
//  ProfileImportantDatesSection.swift
//  FloorMobile
//

import SwiftUI

/// The dates that matter to the client — a birthday, an anniversary —, in the
/// profile's "Profile" tab. A placeholder until `ClientProfile` carries them.
struct ProfileImportantDatesSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Important dates")
        }
    }
}

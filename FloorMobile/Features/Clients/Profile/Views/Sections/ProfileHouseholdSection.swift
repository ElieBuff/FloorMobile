//
//  ProfileHouseholdSection.swift
//  FloorMobile
//

import SwiftUI

/// The client's household — partner, children —, in the profile's "Profile"
/// tab. A placeholder until `ClientProfile` carries it.
struct ProfileHouseholdSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Household")
        }
    }
}

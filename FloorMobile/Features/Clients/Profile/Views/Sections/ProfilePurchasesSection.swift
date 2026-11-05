//
//  ProfilePurchasesSection.swift
//  FloorMobile
//

import SwiftUI

/// What the client bought, in the profile's "Profile" tab. A placeholder
/// until `ClientProfile` carries it.
struct ProfilePurchasesSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Purchases")
        }
    }
}

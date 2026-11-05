//
//  ProfileWishlistSection.swift
//  FloorMobile
//

import SwiftUI

/// The products the client wishes for, in the profile's "Profile" tab. A
/// placeholder until `ClientProfile` carries them.
struct ProfileWishlistSection: View {
    var body: some View {
        Section {
            Text("Coming soon")
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .listRowInsets(.cardRow)
        } header: {
            Text("Wishlist")
        }
    }
}

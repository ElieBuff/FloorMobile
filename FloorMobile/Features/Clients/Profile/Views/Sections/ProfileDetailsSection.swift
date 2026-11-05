//
//  ProfileDetailsSection.swift
//  FloorMobile
//

import SwiftUI

/// How to reach the client and where they belong: their email, phone, store
/// and sales associate, in the profile's "Profile" tab.
struct ProfileDetailsSection: View {
    let client: ClientItem

    var body: some View {
        Section {
            row(String(localized: "Email"), client.primaryEmail)
            row(String(localized: "Phone"), client.primaryPhone)
            row(String(localized: "Store"), client.storeName)
            row(String(localized: "Sales associate"), client.salesAssociateName)
        } header: {
            Text("Details")
        }
    }

    /// A field the client has; nothing for one they do not — a missing email
    /// is not worth a line here.
    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            DetailRow(label: label, value: value)
                .listRowInsets(.cardRow)
        }
    }
}

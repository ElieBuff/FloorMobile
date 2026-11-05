//
//  ProfileDetailsSection.swift
//  FloorMobile
//

import SwiftUI

/// How to reach the client and where they belong, in the profile's "Profile"
/// tab: their card's email, phone, store and sales associate — on screen at
/// once, from the list that opened the profile until the details replace it —
/// then what only their details carry (`ClientProfile.details`): their
/// salutation, address and language.
///
/// While the details are on their way, grey bars stand in for those three.
/// Details that failed leave the card's lines alone: the page's one notice
/// says so.
struct ProfileDetailsSection: View {
    let client: ClientItem
    let details: Loadable<ClientDetails>

    var body: some View {
        Section {
            row(String(localized: "Email"), client.primaryEmail)
            row(String(localized: "Phone"), client.primaryPhone)
            row(String(localized: "Store"), client.storeName)
            row(String(localized: "Sales associate"), client.salesAssociateName)

            switch details {
            case .loading:
                // The salutation, the address on two lines, the language.
                SkeletonLines(widths: [0.4, 0.8, 0.6, 0.45])
                    .listRowInsets(.cardRow)
            case .loaded(let details):
                row(String(localized: "Salutation"), details.salutationLabel)
                address(details.address?.lines ?? [])
                row(String(localized: "Language"), details.languageName)
            case .failed:
                EmptyView()
            }
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

    /// The address line by line, under its label; nothing without one.
    @ViewBuilder
    private func address(_ lines: [String]) -> some View {
        if !lines.isEmpty {
            DetailStackedRow(label: String(localized: "Address"), text: lines.joined(separator: "\n"))
                .listRowInsets(.cardRow)
        }
    }
}

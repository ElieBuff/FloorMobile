//
//  ProfileDetailsSection.swift
//  FloorMobile
//

import SwiftUI

/// How to reach the client and where they belong, in the profile's "Profile"
/// tab: the email, phone, store, sales associate, salutation, address and
/// language of the card on screen — the list's, which opened the profile,
/// until the details replace it (`ClientProfile.details`).
///
/// Every card carries the salutation and the language; only the associate's
/// own clients come with their address. While the details are on their way,
/// grey bars stand in for an address the card lacks. Details that failed
/// leave the card's lines alone: the page's one notice says so.
struct ProfileDetailsSection: View {
    let client: ClientItem
    /// Whether the details are still on their way.
    let isLoading: Bool

    var body: some View {
        Section {
            row(String(localized: "Email"), client.primaryEmail)
            row(String(localized: "Phone"), client.primaryPhone)
            row(String(localized: "Store"), client.storeName)
            row(String(localized: "Sales associate"), client.salesAssociateName)
            row(String(localized: "Salutation"), client.salutationLabel)

            if isLoading && client.address == nil {
                // The address, on two lines.
                SkeletonLines(widths: [0.8, 0.6])
                    .listRowInsets(.insetGroupedRowInsets)
            } else {
                address(client.address?.lines ?? [])
            }

            row(String(localized: "Language"), client.languageName)
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
                .listRowInsets(.insetGroupedRowInsets)
        }
    }

    /// The address line by line, under its label; nothing without one.
    @ViewBuilder
    private func address(_ lines: [String]) -> some View {
        if !lines.isEmpty {
            DetailStackedRow(label: String(localized: "Address"), text: lines.joined(separator: "\n"))
                .listRowInsets(.insetGroupedRowInsets)
        }
    }
}

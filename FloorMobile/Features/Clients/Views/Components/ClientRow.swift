//
//  ClientRow.swift
//  FloorMobile
//

import SwiftUI

/// One client in a list: their initials, their name, and up to two lines of
/// detail beneath.
///
/// Shared by every client list. Each kind of client has its own initializer,
/// which decides what the two lines show and in which order — so a list only
/// hands over its model, and the row reads the same wherever it appears: one
/// of the associate's own clients shows the same lines whether the device or
/// the server found them. A line the client has nothing for is left out; a
/// client with no name on file reads "Unnamed client" rather than a blank
/// line.
struct ClientRow: View {
    private let name: String?
    private let primaryLine: String?
    private let secondaryLine: String?

    /// A client of the store: email, then phone.
    init(client: Client) {
        name = client.displayName
        primaryLine = client.primaryEmail
        secondaryLine = client.primaryPhone
    }

    /// One of the associate's own clients, as the server found them: email,
    /// then phone — the lines of a client the device keeps.
    init(client: MyClient) {
        name = client.displayName
        primaryLine = client.primaryEmail
        secondaryLine = client.primaryPhone
    }

    /// A client of the brand: their store, then the associate they are
    /// assigned to — the server sends neither email nor phone for them.
    init(client: BrandClient) {
        name = client.displayName
        primaryLine = client.storeName
        secondaryLine = client.salesAssociateName
    }

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: name ?? "", size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? String(localized: "Unnamed client"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.OnSurface.textPrimary))

                if let primaryLine, !primaryLine.isEmpty {
                    detail(primaryLine)
                }
                if let secondaryLine, !secondaryLine.isEmpty {
                    detail(secondaryLine)
                }
            }
            .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color(.OnSurface.textSecondary))
    }
}

// MARK: - Previews

#Preview("Each kind of client") {
    List {
        ClientRow(client: Client(
            id: "1", externalId: "1", firstName: "Alice", lastName: "Martinez",
            primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
        ))
        ClientRow(client: Client(
            id: "2", externalId: "2", firstName: "Raphaël", lastName: "Van den Berg",
            primaryPhone: "+33 6 98 76 54 32"
        ))
        ClientRow(client: MyClient(
            id: "3", displayName: "Aliette Martin",
            primaryEmail: "aliette.martin@example.com", primaryPhone: "+33 6 11 22 33 44"
        ))
        ClientRow(client: BrandClient(
            id: "4", displayName: "Nina Larsen", segment: "VIC",
            storeName: "Regent Street", salesAssociateName: "Elie Buff"
        ))
        ClientRow(client: Client(id: "5", externalId: "5"))
    }
    .cardList()
}

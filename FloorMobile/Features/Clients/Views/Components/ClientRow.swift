//
//  ClientRow.swift
//  FloorMobile
//

import SwiftUI

/// One client in a list: their initials, their name, and two lines of detail
/// beneath, which the list chooses by its display style.
///
/// Shared by every client list, whatever the client's source — the server or
/// the device both give a `ClientItem`. The style says what the two lines
/// are, so a row never guesses from what happens to be there: `.mine` shows
/// how to reach the client, `.brand` where they belong. A line the client
/// has nothing for is left out; the name is `ClientItem.displayLabel`, never
/// a blank line.
struct ClientRow: View {
    let client: ClientItem
    let display: Display

    /// What the two lines under the name show.
    enum Display {
        /// The associate's own clients ("My Clients", on the server or the
        /// device): email, then phone.
        case mine
        /// Any client of the brand ("All Brand"): their store, then the
        /// associate they are assigned to — the brand search sends neither
        /// email nor phone for them (their profile does).
        case brand
    }

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: client.displayName ?? "", size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.OnSurface.textPrimary))

                switch display {
                case .mine: MineDetails(client: client)
                case .brand: BrandDetails(client: client)
                }
            }
            .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// How to reach one of the associate's own clients.
private struct MineDetails: View {
    let client: ClientItem

    var body: some View {
        DetailLine(client.primaryEmail)
        DetailLine(client.primaryPhone)
    }
}

/// Where a client of the brand belongs.
private struct BrandDetails: View {
    let client: ClientItem

    var body: some View {
        DetailLine(client.storeName)
        DetailLine(client.salesAssociateName)
    }
}

/// One line of detail in the row's look — nothing at all for a value the
/// client does not have.
private struct DetailLine: View {
    let text: String?

    init(_ text: String?) {
        self.text = text
    }

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(.caption)
                .foregroundStyle(Color(.OnSurface.textSecondary))
        }
    }
}

// MARK: - Previews

#Preview("Both styles") {
    let alice = ClientItem(
        id: "1", displayName: "Alice Martinez", segment: "VIC",
        storeCode: "90917634296", storeName: "Regent Street",
        salesAssociateExternalId: "378970372512460673", salesAssociateName: "Elie Buff",
        primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
    )
    List {
        ClientRow(client: alice, display: .mine)
        ClientRow(client: alice, display: .brand)
        // One of the associate's own clients without a phone: one line only.
        ClientRow(client: ClientItem(
            id: "2", displayName: "Raphaël Van den Berg", segment: nil,
            storeCode: "90917634296", storeName: "Regent Street",
            salesAssociateExternalId: nil, salesAssociateName: nil,
            primaryEmail: "raphael.vandenberg@example.com", primaryPhone: nil
        ), display: .mine)
        // No name on file.
        ClientRow(client: ClientItem(
            id: "3", displayName: nil, segment: nil, storeCode: nil, storeName: nil,
            salesAssociateExternalId: nil, salesAssociateName: nil, primaryEmail: nil, primaryPhone: nil
        ), display: .mine)
    }
    .cardList()
}

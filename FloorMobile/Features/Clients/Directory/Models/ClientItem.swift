//
//  ClientItem.swift
//  FloorMobile
//

import Foundation

/// A client as a list shows them, wherever they come from: a card the server
/// found (`client/search`), or a client the device keeps (`Client`) — and the
/// card a client's details carry (`ClientDetails`, `client/{id}`).
///
/// A plain value, never stored: it lives as long as the list, or the profile
/// page, that shows it. In a list, the email and the phone are there only for
/// the associate's own clients — a search never sends them for a client of
/// the brand; a profile has them for any client. `storeCode` and
/// `salesAssociateExternalId` say whose client it is, by the server's ids:
/// what a list mixing the brand's clients and the associate's own will read
/// to show each one its way. No view reads them yet.
///
/// Not a `ClientSnapshot`: that one is stored as a composite in shipped models
/// (`AgendaEvent`, `AgendaTask`, `AIAction`), so growing it with the email and
/// the phone would change their store's shape.
///
/// `Hashable` and `Codable` for the route that opens a profile, which carries
/// the row the list showed (`ClientsRoute.profile`): navigation and its
/// restoration, never the network — the server's shapes stay in their wires.
nonisolated struct ClientItem: Identifiable, Sendable, Hashable, Codable {
    let id: String
    /// "Raphaël Van den Berg", or `nil` when there is no name.
    let displayName: String?
    let segment: String?
    let storeCode: String?
    /// The client's store, e.g. "Regent Street".
    let storeName: String?
    let salesAssociateExternalId: String?
    /// The associate the client is assigned to.
    let salesAssociateName: String?
    let primaryEmail: String?
    let primaryPhone: String?
}

nonisolated extension ClientItem {
    /// A client the device keeps: the same card, stored.
    init(client: Client) {
        self.init(
            id: client.id,
            displayName: client.displayName,
            segment: client.segment,
            storeCode: client.storeCode,
            storeName: client.store?.name,
            salesAssociateExternalId: client.salesAssociateExternalId,
            salesAssociateName: client.salesAssociate?.displayName,
            primaryEmail: client.primaryEmail,
            primaryPhone: client.primaryPhone
        )
    }

    /// A card the server sent, the name, the store and the associate
    /// flattened into display names. Here rather than in `ClientWire.swift`,
    /// which converts the card for its own model, `Client`: a second model
    /// built from the same card converts it in its own file, as one built
    /// from a shared wire fragment does (`StoreSnapshot.init(wire:)`).
    init(wire: ClientWire.Response) {
        self.init(
            id: wire.id,
            displayName: PersonName.display(first: wire.firstName, last: wire.lastName),
            segment: wire.segment,
            storeCode: wire.storeCode,
            storeName: wire.store?.name,
            salesAssociateExternalId: wire.salesAssociateExternalId,
            salesAssociateName: wire.salesAssociate.flatMap {
                PersonName.display(first: $0.firstName, last: $0.lastName)
            },
            primaryEmail: wire.primaryEmail,
            primaryPhone: wire.primaryPhone
        )
    }

    /// The card of a client's details (`client/{id}`): the same flattening as
    /// a list's card, from the details' own shape — the email and the phone
    /// under their names there, the store's code and the associate's
    /// external id inside the projections they come in.
    init(wire: ClientDetailsWire.Response) {
        self.init(
            id: wire.id,
            displayName: PersonName.display(first: wire.firstName, last: wire.lastName),
            segment: wire.segment,
            storeCode: wire.store?.storeCode,
            storeName: wire.store?.name,
            salesAssociateExternalId: wire.salesAssociate?.externalId,
            salesAssociateName: wire.salesAssociate.flatMap {
                PersonName.display(first: $0.firstName, last: $0.lastName)
            },
            primaryEmail: wire.email,
            primaryPhone: wire.mobile
        )
    }
}

nonisolated extension ClientItem {

    // MARK: - Display

    /// The name to write: the client's, or "Unnamed client" when the server
    /// has none — never a blank line. What every row, title and header reads;
    /// an avatar keeps `displayName`, so a client with no name gets an empty
    /// circle rather than the placeholder's initials.
    var displayLabel: String {
        displayName ?? String(localized: "Unnamed client")
    }
}

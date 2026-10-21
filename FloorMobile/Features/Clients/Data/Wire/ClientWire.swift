//
//  ClientWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a client: the one card the server sends for every client
/// list — the store's clients the device keeps (`client/sync`), the
/// associate's own clients a search finds (`client/search?scope=mine`), and
/// any client of the brand (`client/search`) — and that a client's profile
/// (`client/{id}`) holds among its columns. Read-only: the app does not write
/// clients yet, so there is no `Request`.
///
/// One card for three readers, to keep in step with it: `Client` keeps it
/// (`init(wire:)`, below), `ClientItem` shows it (`ClientItem.init(wire:)`,
/// in its own file), and `ClientProfileWire` reads it from a profile. Not the
/// recent clients: theirs comes embedded, as `ClientSummaryWire`.
nonisolated enum ClientWire {
    /// One client card: of a page — the page itself decodes as a `CursorPage`
    /// (the sync's `storeCode` on it is not needed) — or of a profile
    /// (`ClientProfileWire`). In a list, the store and the associate come as
    /// the shared projections an agenda item embeds them with; a profile's
    /// store carries only `storeCode` and `name`.
    ///
    /// What a card carries depends on where it comes from. In a list, the
    /// email, the phone and the search's words — drawn from the name, the
    /// email and the phone — come only for the associate's own clients (the
    /// sync, "My Clients"), never for a client of the brand. A profile
    /// (`client/{id}`) carries the email and the phone of any client it
    /// opens, but never the search's words.
    struct Response: Decodable, Sendable {
        var id: String
        var externalId: String
        var firstName: String?
        var lastName: String?
        var segment: String?
        var storeCode: String?
        /// The client's store, for its name. Absent from a BFF that does not
        /// send it yet.
        var store: StoreWire?
        var salesAssociateExternalId: String?
        var salesAssociate: SalesAssociateWire?
        var primaryEmail: String?
        var primaryPhone: String?
        /// The words the server finds the client by — the first name's, the
        /// last name's and the email's before its @, folded, each multi-word
        /// value also glued — and its phone numbers as digits: what the
        /// server's `floor_clients_search_columns` writes.
        var searchWords: [String]?
        var searchPhones: [String]?

        /// The server spells the associate `SA`; the app spells it out.
        enum CodingKeys: String, CodingKey {
            case id, externalId, firstName, lastName, segment, storeCode, store
            case salesAssociateExternalId = "SAExternalId"
            case salesAssociate = "SA"
            case primaryEmail, primaryPhone, searchWords, searchPhones
        }
    }

    /// Every client id of the store, as `client/store-ids` serves it — what
    /// the device checks its own copy against.
    struct StoreIDs: Decodable, Sendable {
        var storeCode: String
        var ids: [String]
    }
}

nonisolated extension Client {
    /// Maps the card into the local model, the store and the associate kept
    /// as display snapshots; search words a card leaves out become empty
    /// lists.
    convenience init(wire: ClientWire.Response) {
        self.init(
            id: wire.id,
            externalId: wire.externalId,
            firstName: wire.firstName,
            lastName: wire.lastName,
            primaryEmail: wire.primaryEmail,
            primaryPhone: wire.primaryPhone,
            segment: wire.segment,
            storeCode: wire.storeCode,
            store: wire.store.map(StoreSummary.init(wire:)),
            salesAssociateExternalId: wire.salesAssociateExternalId,
            salesAssociate: wire.salesAssociate.map(SalesAssociateSummary.init(wire:)),
            searchWords: wire.searchWords ?? [],
            searchPhones: wire.searchPhones ?? []
        )
    }
}

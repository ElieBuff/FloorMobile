//
//  ClientWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a client: the one card the server sends for every client
/// list — the store's clients the device keeps (`client/sync`), the
/// associate's own clients a search finds (`client/search?scope=mine`), and
/// any client of the brand (`client/search`). The app writes a client through
/// their details (`ClientDetailsWire.Request`), not this card.
///
/// One card for two readers, to keep in step with it: `Client` keeps it
/// (`init(wire:)`, below), `ClientItem` shows it (`ClientItem.init(wire:)`,
/// in its own file). Not a client's details (`client/{id}`), which have their
/// own shape (`ClientDetailsWire`) but share this file's address and consents.
nonisolated enum ClientWire {
    /// One client card of a page — the page itself decodes as a `CursorPage`
    /// (the sync's `storeCode` on it is not needed). The store and the
    /// associate come as the shared projections an agenda item embeds them
    /// with.
    ///
    /// The email, the phone, the address, the consents and the search's
    /// words — drawn from the name, the email and the phone — come only for
    /// the associate's own clients (the sync, "My Clients"), never for a
    /// client of the brand. The salutation, the language, the address and the
    /// consents are absent from a BFF that does not send them yet.
    struct Response: Decodable, Sendable {
        var id: String
        var externalId: String
        var firstName: String?
        var lastName: String?
        var segment: String?
        var storeCode: String?
        /// The client's store, for its name. Absent from a BFF that does not
        /// send it yet.
        var store: StoreSnapshotWire?
        var salesAssociateExternalId: String?
        var salesAssociate: SalesAssociateSnapshotWire?
        var primaryEmail: String?
        var primaryPhone: String?
        /// The words the server finds the client by — the first name's, the
        /// last name's and the email's before its @, folded, each multi-word
        /// value also glued — and its phone numbers as digits: what the
        /// server's `floor_clients_search_columns` writes.
        var searchWords: [String]?
        var searchPhones: [String]?
        /// The server's own value (`mister`, `misses`, `miss`), an open set.
        var salutation: String?
        /// An ISO 639-1 code ("fr", "en", "zh").
        var preferredLanguage: String?
        var mainAddress: Address?
        var optIns: OptIns?

        /// The server spells the associate `SA` and the consents `optins`;
        /// the app spells them out.
        enum CodingKeys: String, CodingKey {
            case id, externalId, firstName, lastName, segment, storeCode, store
            case salesAssociateExternalId = "SAExternalId"
            case salesAssociate = "SA"
            case primaryEmail, primaryPhone, searchWords, searchPhones
            case salutation, preferredLanguage, mainAddress
            case optIns = "optins"
        }
    }

    /// A client's main address, as every client response sends it — this
    /// card and a client's details (`ClientDetailsWire`). Among several, the
    /// server sends the default one. The street holds both street lines,
    /// joined by a comma; the country is as the source wrote it, a code or a
    /// name. Read-only: what the app writes is
    /// `ClientDetailsWire.Request.Address`.
    struct Address: Decodable, Sendable {
        var street: String?
        var postalCode: String?
        var city: String?
        var state: String?
        var country: String?
    }

    /// What a client agreed to be reached by, as every client response sends
    /// it — this card and a client's details (`ClientDetailsWire`). Read-only:
    /// what the app writes is `ClientDetailsWire.Request.OptIns`.
    struct OptIns: Decodable, Sendable {
        var email: Bool
        /// Instant messaging: WhatsApp, SMS.
        var directMessage: Bool
        /// A call on their phone.
        var call: Bool
        var wechat: Bool
        var line: Bool
    }

    /// Every client id of the store, as `client/store-ids` serves it — what
    /// the device checks its own copy against.
    struct StoreIDs: Decodable, Sendable {
        var storeCode: String
        var ids: [String]
    }

    /// How many clients a search would list, as `client/count` serves it.
    struct Count: Decodable, Sendable {
        var total: Int
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
            store: wire.store.map(StoreSnapshot.init(wire:)),
            salesAssociateExternalId: wire.salesAssociateExternalId,
            salesAssociate: wire.salesAssociate.map(SalesAssociateSnapshot.init(wire:)),
            searchWords: wire.searchWords ?? [],
            searchPhones: wire.searchPhones ?? [],
            salutation: wire.salutation,
            preferredLanguage: wire.preferredLanguage,
            address: wire.mainAddress.map(ClientItem.Address.init(wire:)),
            optIns: wire.optIns.map(ClientItem.OptIns.init(wire:))
        )
    }
}

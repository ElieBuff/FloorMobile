//
//  ClientWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a client: the one card the server sends for every client
/// route — one client (`client/{id}`, and an edit's answer), the store's
/// clients the device keeps (`client/sync`), the associate's own clients a
/// search finds (`client/search?scope=mine`), and their recent clients
/// (`client/recent`) — and the edit the app sends (`Request`,
/// `PATCH client/{id}`).
///
/// One card for two readers, to keep in step with it: `Client` keeps it
/// (`init(wire:)`, below), `ClientItem` shows it (`ClientItem.init(wire:)`,
/// in its own file).
nonisolated enum ClientWire {
    /// One client card — of a page, which decodes as a `CursorPage` (the
    /// sync's `storeCode` on it is not needed), of the recent clients
    /// (`Recents`), or alone. The store and the associate come as the shared
    /// projections an agenda item embeds them with.
    ///
    /// The email, the phone, the address, the consents and the search's
    /// words — drawn from the name, the email and the phone — are left out
    /// of a card the server has none for (`client_search_page.json`, a card
    /// read in tests, has no email or phone). The salutation, the language,
    /// the address and the consents are absent from a BFF that does not send
    /// them yet.
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

    /// A client's main address, as the card sends it. Among several, the
    /// server sends the default one. The street holds both street lines,
    /// joined by a comma; the country is as the source wrote it, a code or a
    /// name. Read-only: what the app writes is `Request.Address`.
    struct Address: Decodable, Sendable {
        var street: String?
        var postalCode: String?
        var city: String?
        var state: String?
        var country: String?
    }

    /// What a client agreed to be reached by, as the card sends it.
    /// Read-only: what the app writes is `Request.OptIns`.
    struct OptIns: Decodable, Sendable {
        var email: Bool
        /// Instant messaging: WhatsApp, SMS.
        var directMessage: Bool
        /// A call on their phone.
        var call: Bool
        var wechat: Bool
        var line: Bool
    }

    /// The associate's recent clients, the latest view first, as
    /// `client/recent` serves them. Each card also carries `lastViewedAt`,
    /// which the app does not show.
    struct Recents: Decodable, Sendable {
        var items: [Response]
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

    /// An edit, as `PATCH client/{id}` takes it — a true PATCH: only what
    /// changed is sent. Each field is a double optional, encoded as Swift
    /// synthesizes it: `nil` leaves the key out (unchanged), `.some(nil)`
    /// sends `null` (cleared), `.some(value)` the value.
    ///
    /// The email and the phone go as `email` and `mobile`, the names the
    /// `PATCH` route was specified with, where the card says `primaryEmail`
    /// and `primaryPhone`: the route is not written yet, the names are the
    /// server's to settle (skill `release`).
    ///
    /// The consents go only when they change, and then always with the
    /// client's signature, beside them: the server refuses one without the
    /// other (422).
    struct Request: Encodable, Sendable {
        var firstName: String?? = nil
        var lastName: String?? = nil
        var email: String?? = nil
        var mobile: String?? = nil
        /// Sent whole as soon as one of its lines changes; `null` once every
        /// line is cleared.
        var mainAddress: Address?? = nil
        var optIns: OptIns? = nil
        var signature: Signature? = nil

        /// The server spells the consents `optins`.
        enum CodingKeys: String, CodingKey {
            case firstName, lastName, email, mobile, mainAddress
            case optIns = "optins"
            case signature
        }

        /// What `edited` changes from `original`, both compared as an edit
        /// sends them (`ClientItem.normalized`) — the same rule the editor's
        /// "Save" reads, so what it lets through is what goes. `signature`
        /// goes only with changed consents.
        init(edited: ClientItem, original: ClientItem, signature: ClientSignature?) {
            let edited = edited.normalized
            let original = original.normalized
            firstName = Self.change(edited.firstName, from: original.firstName)
            lastName = Self.change(edited.lastName, from: original.lastName)
            email = Self.change(edited.primaryEmail, from: original.primaryEmail)
            mobile = Self.change(edited.primaryPhone, from: original.primaryPhone)
            if edited.address != original.address {
                mainAddress = .some(edited.address.map(Address.init(address:)))
            }
            if let optIns = edited.optIns, optIns != original.optIns {
                self.optIns = OptIns(optIns: optIns)
                self.signature = signature.map(Signature.init(signature:))
            }
        }

        /// The address as an edit writes it: its five keys always there, a
        /// cleared line `null` — never a missing key, which the server would
        /// read as "unchanged". By hand for that: Swift would drop a `nil`.
        struct Address: Encodable, Sendable {
            var street: String?
            var postalCode: String?
            var city: String?
            var state: String?
            var country: String?

            init(address: ClientItem.Address) {
                street = address.street
                postalCode = address.postalCode
                city = address.city
                state = address.state
                country = address.country
            }

            enum CodingKeys: String, CodingKey {
                case street, postalCode, city, state, country
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(street, forKey: .street)
                try container.encode(postalCode, forKey: .postalCode)
                try container.encode(city, forKey: .city)
                try container.encode(state, forKey: .state)
                try container.encode(country, forKey: .country)
            }
        }

        /// Every consent, as the client signed them.
        struct OptIns: Encodable, Sendable {
            var email: Bool
            var directMessage: Bool
            var call: Bool
            var wechat: Bool
            var line: Bool

            init(optIns: ClientItem.OptIns) {
                email = optIns.email
                directMessage = optIns.directMessage
                call = optIns.call
                wechat = optIns.wechat
                line = optIns.line
            }
        }

        /// The client's signature: the PNG — base64 in the JSON, by
        /// `JSONEncoder`'s default `Data` strategy, which `APIClient` keeps —
        /// and when they signed, in ISO 8601.
        struct Signature: Encodable, Sendable {
            var image: Data
            var signedAt: Date

            init(signature: ClientSignature) {
                image = signature.png
                signedAt = signature.signedAt
            }
        }

        /// `nil` when the value is unchanged — the key left out —, else the
        /// new value, `nil` included.
        private static func change(_ value: String?, from original: String?) -> String?? {
            value == original ? nil : .some(value)
        }
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

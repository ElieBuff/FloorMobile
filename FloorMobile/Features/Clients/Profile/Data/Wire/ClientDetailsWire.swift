//
//  ClientDetailsWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a client's details: what `client/{id}` serves — who one
/// client of the brand is, bounded: their purchases and messages are the
/// timeline's (`ClientTimelineWire`) — and what an edit sends to the same
/// path (`PATCH`), which answers with the details again. Read as a
/// `ClientItem` (`ClientItem.init(wire:)`, in its own file).
nonisolated enum ClientDetailsWire {
    /// One client's details. The store and the associate come as the shared
    /// projections an agenda item embeds them with; the address and the
    /// consents as every client response sends them (`ClientWire.Address`,
    /// `ClientWire.OptIns`).
    ///
    /// The server also sends `importantDates`, `household` and `preferences`,
    /// always empty for now: they are read once it fills them.
    struct Response: Decodable, Sendable {
        var id: String
        var externalId: String
        /// The server's own value (`mister`, `misses`, `miss`), an open set.
        var salutation: String?
        var firstName: String?
        var lastName: String?
        var email: String?
        var mobile: String?
        /// The client's loyalty segment. Not sent yet: the server is to add
        /// it, the profile's header shows it.
        var segment: String?
        var mainAddress: ClientWire.Address?
        /// An ISO 639-1 code ("fr", "en", "zh").
        var preferredLanguage: String?
        var salesAssociate: SalesAssociateSnapshotWire?
        var store: StoreSnapshotWire?
        var optIns: ClientWire.OptIns

        /// The server spells the consents `optins`.
        enum CodingKeys: String, CodingKey {
            case id, externalId, salutation, firstName, lastName, email, mobile, segment
            case mainAddress, preferredLanguage, salesAssociate, store
            case optIns = "optins"
        }
    }

    /// An edit, as `PATCH client/{id}` takes it — a true PATCH: only what
    /// changed is sent. Each field is a double optional, encoded as Swift
    /// synthesizes it: `nil` leaves the key out (unchanged), `.some(nil)`
    /// sends `null` (cleared), `.some(value)` the value.
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

//
//  ClientDetailsWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of `ClientDetails`: what `client/{id}` serves — who one
/// client of the brand is, bounded: their purchases and messages are the
/// timeline's (`ClientTimelineWire`). Read-only.
nonisolated enum ClientDetailsWire {
    /// One client's details. The card (`ClientItem`) is read from it by
    /// `ClientItem.init(wire:)`, in its own file; the rest by
    /// `ClientDetails.init(wire:)`, below. The store and the associate come
    /// as the shared projections an agenda item embeds them with.
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
        var mainAddress: Address?
        /// An ISO 639-1 code ("fr", "en", "zh").
        var preferredLanguage: String?
        var salesAssociate: SalesAssociateSnapshotWire?
        var store: StoreSnapshotWire?
        var optIns: OptIns

        /// The server spells the consents `optins`.
        enum CodingKeys: String, CodingKey {
            case id, externalId, salutation, firstName, lastName, email, mobile, segment
            case mainAddress, preferredLanguage, salesAssociate, store
            case optIns = "optins"
        }
    }

    /// The client's only address — among several, the default one. The street
    /// holds both street lines, joined by a comma; the country is as the
    /// source wrote it, a code or a name.
    struct Address: Decodable, Sendable {
        var street: String?
        var postalCode: String?
        var city: String?
        var state: String?
        var country: String?
    }

    /// What the client agreed to be reached by.
    struct OptIns: Decodable, Sendable {
        var email: Bool
        /// Instant messaging: WhatsApp, SMS.
        var directMessage: Bool
        /// A call on their phone.
        var call: Bool
        var wechat: Bool
        var line: Bool
    }
}

nonisolated extension ClientDetails {
    /// Maps the wire format into what the profile shows: the card, as every
    /// client list shows it, then what only the details carry.
    init(wire: ClientDetailsWire.Response) {
        self.init(
            client: ClientItem(wire: wire),
            salutation: wire.salutation,
            address: wire.mainAddress.map {
                Address(street: $0.street, postalCode: $0.postalCode, city: $0.city, state: $0.state, country: $0.country)
            },
            preferredLanguage: wire.preferredLanguage,
            optIns: OptIns(
                email: wire.optIns.email,
                directMessage: wire.optIns.directMessage,
                call: wire.optIns.call,
                wechat: wire.optIns.wechat,
                line: wire.optIns.line
            )
        )
    }
}

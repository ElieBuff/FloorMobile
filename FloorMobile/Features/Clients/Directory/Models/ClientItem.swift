//
//  ClientItem.swift
//  FloorMobile
//

import Foundation

/// A client as the app knows them: their base data, wherever it comes from —
/// a card the server found (`client/search`), a client the device keeps
/// (`Client`), or a client's details (`client/{id}`). The one client value
/// every list, the profile and its editor read.
///
/// A plain value: it lives as long as the list, or the profile page, that
/// shows it. A field can be missing for a client of the brand: a search never
/// sends their email, phone, address or consents — the associate's own
/// clients (the sync, "My Clients") and any client's details have them.
/// `storeCode` and `salesAssociateExternalId` say whose client it is, by the
/// server's ids (`isAssigned(to:)`).
///
/// Not a `ClientSnapshot`, which shipped models embed as a composite with a
/// few names only. Its `Address` and `OptIns` are stored, though — as
/// composites of `Client`.
///
/// `Hashable` and `Codable` for the route that opens a profile, which carries
/// the row the list showed (`ClientsRoute.profile`), and for `Client`'s
/// composites: navigation and the store, never the network — the server's
/// shapes stay in their wires.
///
/// What an edit can change is a `var` — the names, the email, the phone, the
/// address, the consents —, the rest a `let`: the editor (`ClientEditorView`)
/// works on a copy, and the type itself says what it may touch.
nonisolated struct ClientItem: Identifiable, Sendable, Hashable, Codable {
    let id: String
    var firstName: String?
    var lastName: String?
    let segment: String?
    let storeCode: String?
    /// The client's store, e.g. "Regent Street".
    let storeName: String?
    let salesAssociateExternalId: String?
    /// The associate the client is assigned to.
    let salesAssociateName: String?
    var primaryEmail: String?
    var primaryPhone: String?
    /// The server's own value (`mister`, `misses`, `miss`), an open set, as
    /// received.
    let salutation: String?
    /// Their main address; `nil` when the server has none, or sent none.
    var address: Address?
    /// An ISO 639-1 code ("fr", "en", "zh").
    let preferredLanguage: String?
    /// What they agreed to be reached by; `nil` when the server sent none — a
    /// client of the brand found by a search.
    var optIns: OptIns?

    init(
        id: String,
        firstName: String? = nil,
        lastName: String? = nil,
        segment: String? = nil,
        storeCode: String? = nil,
        storeName: String? = nil,
        salesAssociateExternalId: String? = nil,
        salesAssociateName: String? = nil,
        primaryEmail: String? = nil,
        primaryPhone: String? = nil,
        salutation: String? = nil,
        address: Address? = nil,
        preferredLanguage: String? = nil,
        optIns: OptIns? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.segment = segment
        self.storeCode = storeCode
        self.storeName = storeName
        self.salesAssociateExternalId = salesAssociateExternalId
        self.salesAssociateName = salesAssociateName
        self.primaryEmail = primaryEmail
        self.primaryPhone = primaryPhone
        self.salutation = salutation
        self.address = address
        self.preferredLanguage = preferredLanguage
        self.optIns = optIns
    }

    /// Whether the client is assigned to the associate of that external id —
    /// the signed-in one's is `User.id`, the token's `sub`. A missing id, on
    /// either side, never matches.
    func isAssigned(to associateID: String?) -> Bool {
        guard let associateID, let salesAssociateExternalId else { return false }
        return salesAssociateExternalId == associateID
    }

    /// A client's main address, each line as the source wrote it.
    ///
    /// Stored as a composite of `Client`: adding, removing or renaming a
    /// field here changes the store's shape (`FloorSchema`).
    nonisolated struct Address: Sendable, Hashable, Codable {
        /// Both street lines, joined by a comma.
        var street: String?
        var postalCode: String?
        var city: String?
        var state: String?
        /// A code ("FR") or a name, as the source wrote it.
        var country: String?
    }

    /// What a client agreed to be reached by, channel by channel.
    ///
    /// Stored as a composite of `Client`: adding, removing or renaming a
    /// field here changes the store's shape (`FloorSchema`).
    nonisolated struct OptIns: Sendable, Hashable, Codable {
        var email: Bool
        /// Instant messaging: WhatsApp, SMS.
        var directMessage: Bool
        /// A call on their phone.
        var call: Bool
        var wechat: Bool
        var line: Bool

        /// One channel's consent.
        subscript(channel channel: Channel) -> Bool {
            get { self[keyPath: channel.keyPath] }
            set { self[keyPath: channel.keyPath] = newValue }
        }

        /// The channels whose consent differs from `other`'s, in their order.
        func changedChannels(from other: OptIns) -> [Channel] {
            Channel.allCases.filter { self[channel: $0] != other[channel: $0] }
        }

        /// A channel a client can agree to be reached by — written once, for
        /// the profile, the editor and the signature to list alike.
        nonisolated enum Channel: CaseIterable, Sendable {
            case email
            case directMessage
            case call
            case wechat
            case line

            var keyPath: WritableKeyPath<OptIns, Bool> {
                switch self {
                case .email: \.email
                case .directMessage: \.directMessage
                case .call: \.call
                case .wechat: \.wechat
                case .line: \.line
                }
            }
        }
    }
}

nonisolated extension ClientItem {
    /// A client the device keeps: the same card, stored.
    init(client: Client) {
        self.init(
            id: client.id,
            firstName: client.firstName,
            lastName: client.lastName,
            segment: client.segment,
            storeCode: client.storeCode,
            storeName: client.store?.name,
            salesAssociateExternalId: client.salesAssociateExternalId,
            salesAssociateName: client.salesAssociate?.displayName,
            primaryEmail: client.primaryEmail,
            primaryPhone: client.primaryPhone,
            salutation: client.salutation,
            address: client.address,
            preferredLanguage: client.preferredLanguage,
            optIns: client.optIns
        )
    }

    /// A card the server sent, the store and the associate flattened into
    /// display names. Here rather than in `ClientWire.swift`, which converts
    /// the card for its own model, `Client`: a second model built from the
    /// same card converts it in its own file, as one built from a shared wire
    /// fragment does (`StoreSnapshot.init(wire:)`).
    init(wire: ClientWire.Response) {
        self.init(
            id: wire.id,
            firstName: wire.firstName,
            lastName: wire.lastName,
            segment: wire.segment,
            storeCode: wire.storeCode,
            storeName: wire.store?.name,
            salesAssociateExternalId: wire.salesAssociateExternalId,
            salesAssociateName: wire.salesAssociate.flatMap {
                PersonName.display(first: $0.firstName, last: $0.lastName)
            },
            primaryEmail: wire.primaryEmail,
            primaryPhone: wire.primaryPhone,
            salutation: wire.salutation,
            address: wire.mainAddress.map(Address.init(wire:)),
            preferredLanguage: wire.preferredLanguage,
            optIns: wire.optIns.map(OptIns.init(wire:))
        )
    }

    /// A client's details (`client/{id}`): the same card, from the details'
    /// own shape — the email and the phone under their names there, the
    /// store's code and the associate's external id inside the projections
    /// they come in.
    init(wire: ClientDetailsWire.Response) {
        self.init(
            id: wire.id,
            firstName: wire.firstName,
            lastName: wire.lastName,
            segment: wire.segment,
            storeCode: wire.store?.storeCode,
            storeName: wire.store?.name,
            salesAssociateExternalId: wire.salesAssociate?.externalId,
            salesAssociateName: wire.salesAssociate.flatMap {
                PersonName.display(first: $0.firstName, last: $0.lastName)
            },
            primaryEmail: wire.email,
            primaryPhone: wire.mobile,
            salutation: wire.salutation,
            address: wire.mainAddress.map(Address.init(wire:)),
            preferredLanguage: wire.preferredLanguage,
            optIns: OptIns(wire: wire.optIns)
        )
    }
}

nonisolated extension ClientItem.Address {
    init(wire: ClientWire.Address) {
        self.init(
            street: wire.street, postalCode: wire.postalCode, city: wire.city,
            state: wire.state, country: wire.country
        )
    }
}

nonisolated extension ClientItem.OptIns {
    init(wire: ClientWire.OptIns) {
        self.init(
            email: wire.email, directMessage: wire.directMessage, call: wire.call,
            wechat: wire.wechat, line: wire.line
        )
    }
}

nonisolated extension ClientItem {

    // MARK: - Edit

    /// The client as an edit sends them: each editable field without its
    /// surrounding spaces, a blank one `nil`, an address left with no line
    /// `nil`. The one rule of what changed — the editor's "Save" and the
    /// request (`ClientDetailsWire.Request`) both compare on it, so a space
    /// typed after a name changes nothing.
    var normalized: ClientItem {
        var client = self
        client.firstName = firstName?.trimmedNonBlank
        client.lastName = lastName?.trimmedNonBlank
        client.primaryEmail = primaryEmail?.trimmedNonBlank
        client.primaryPhone = primaryPhone?.trimmedNonBlank
        client.address = address?.normalized
        return client
    }

    /// Whether the edit changes anything the server would be sent.
    func hasChanges(from original: ClientItem) -> Bool {
        normalized != original.normalized
    }

    /// Whether the edit can be sent, judging only what it sends: a name
    /// changed leaves at least one, an email changed is well formed or
    /// cleared. A client imported without a name, or with a broken email, can
    /// still have their phone corrected — what is not sent, the server does
    /// not judge either.
    func isValid(from original: ClientItem) -> Bool {
        let edited = normalized
        let before = original.normalized
        let namesChanged = edited.firstName != before.firstName || edited.lastName != before.lastName
        let keepsAName = edited.firstName != nil || edited.lastName != nil
        return (!namesChanged || keepsAName) && isEmailValid(from: original)
    }

    /// Whether the email is fit to send: unchanged, cleared, or well formed
    /// by the server's rule — the BFF's write schema checks it with zod's
    /// `z.email()`, whose pattern this is (zod 4.3). What the editor's
    /// message under the field reads too.
    func isEmailValid(from original: ClientItem) -> Bool {
        let email = normalized.primaryEmail
        guard email != original.normalized.primaryEmail, let email else { return true }
        let pattern = #/(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-\.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}/#
        return email.wholeMatch(of: pattern) != nil
    }
}

nonisolated extension ClientItem.Address {

    // MARK: - Edit

    /// Each line without its surrounding spaces, a blank one `nil`; `nil`
    /// when no line is left (`ClientItem.normalized`).
    var normalized: ClientItem.Address? {
        let address = ClientItem.Address(
            street: street?.trimmedNonBlank, postalCode: postalCode?.trimmedNonBlank,
            city: city?.trimmedNonBlank, state: state?.trimmedNonBlank, country: country?.trimmedNonBlank
        )
        return address == ClientItem.Address() ? nil : address
    }
}

nonisolated extension ClientItem {

    // MARK: - Display

    /// "Raphaël Van den Berg", "Raphaël", "Van den Berg", or `nil` when there
    /// is no name.
    var displayName: String? {
        PersonName.display(first: firstName, last: lastName)
    }

    /// The name to write: the client's, or "Unnamed client" when the server
    /// has none — never a blank line. What every row, title and header reads;
    /// an avatar keeps `displayName`, so a client with no name gets an empty
    /// circle rather than the placeholder's initials.
    var displayLabel: String {
        displayName ?? String(localized: "Unnamed client")
    }

    /// "Mr", "Mrs" or "Miss"; `nil` without a salutation, or for one this
    /// build does not know — nothing rather than a raw code.
    var salutationLabel: String? {
        switch salutation {
        case "mister": String(localized: "Mr")
        case "misses": String(localized: "Mrs")
        case "miss": String(localized: "Miss")
        default: nil
        }
    }

    /// The language's name in the device's ("French" for "fr"); the code
    /// itself when the system does not know it.
    var languageName: String? {
        preferredLanguage.map { Locale.current.localizedString(forLanguageCode: $0) ?? $0 }
    }
}

nonisolated extension ClientItem.Address {

    // MARK: - Display

    /// The address as written on an envelope: the street, the postal code and
    /// the city, the state, the country — named in the device's language when
    /// the source gave a two-letter code. A line the source left empty is left
    /// out.
    var lines: [String] {
        let place = [postalCode, city]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let countryName = country.map { country in
            country.count == 2 ? Locale.current.localizedString(forRegionCode: country) ?? country : country
        }
        return [street, place, state, countryName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }
}

nonisolated extension ClientItem.OptIns {

    // MARK: - Display

    /// "Yes" or "No": the client's answer for one channel, as the consents
    /// read — the profile's and the signature's alike.
    func answer(for channel: Channel) -> String {
        self[channel: channel] ? String(localized: "Yes") : String(localized: "No")
    }
}

nonisolated extension ClientItem.OptIns.Channel {

    // MARK: - Display

    /// The channel's name, as the consents read.
    var label: String {
        switch self {
        case .email: String(localized: "Email")
        case .directMessage: String(localized: "Messages")
        case .call: String(localized: "Phone call")
        case .wechat: String(localized: "WeChat")
        case .line: String(localized: "LINE")
        }
    }
}

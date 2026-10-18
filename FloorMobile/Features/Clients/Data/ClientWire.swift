//
//  ClientWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of the store's `Client`s: what `client/sync` and
/// `client/filter` serve to keep the device's copy. Read-only — the app does
/// not write clients yet, so there is no `Request`. The brand's clients, a
/// different model, have their own file (`BrandClientWire`).
nonisolated enum ClientWire {
    /// A client exactly as `client/sync` serves it, one item of a page. The
    /// page itself decodes as a `CursorPage` (its `storeCode` is not needed).
    struct Response: Decodable, Sendable {
        var id: String
        var externalId: String
        var firstName: String?
        var lastName: String?
        var primaryEmail: String?
        var primaryPhone: String?
        var segment: String?
        var storeCode: String?
        var optinEmail: Bool
        var optinPhone: Bool
        var optinIM: Bool
        var salesAssociateExternalId: String?
        var salesAssociate: SalesAssociateWire?
        var totalSpent12M: Int
        var totalSpentLifetime: Int
        var numTransactions12M: Int
        var firstTransactionAt: Date?
        var lastTransactionAt: Date?
        var lastInteractionAt: Date?
        var preferredChannel: String?
        var rfmRecency12M: Int?
        var rfmFrequency12M: Int?
        var rfmMonetary12M: Int?
        /// The words the server finds the client by — the first name's, the last
        /// name's and the email's before its @, folded, each multi-word value also
        /// glued — and its phone numbers as digits: what the server's
        /// `floor_clients_search_columns` writes. Arrays, `[]` when empty, never
        /// null.
        var searchWords: [String]
        var searchPhones: [String]

        /// The server spells the associate `SA`; the app spells it out.
        enum CodingKeys: String, CodingKey {
            case id, externalId, firstName, lastName, primaryEmail, primaryPhone
            case segment, storeCode, optinEmail, optinPhone, optinIM
            case salesAssociateExternalId = "SAExternalId"
            case salesAssociate = "SA"
            case totalSpent12M, totalSpentLifetime, numTransactions12M
            case firstTransactionAt, lastTransactionAt, lastInteractionAt
            case preferredChannel, rfmRecency12M, rfmFrequency12M, rfmMonetary12M
            case searchWords, searchPhones
        }
    }

    /// Every client id of the store, as `client/filter` serves it without a
    /// filter — what the device checks its own copy against.
    struct StoreIDs: Decodable, Sendable {
        var storeCode: String
        var ids: [String]
    }
}

nonisolated extension Client {
    /// Maps the wire format into the local model, flattening the associate.
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
            optinEmail: wire.optinEmail,
            optinPhone: wire.optinPhone,
            optinIM: wire.optinIM,
            salesAssociateExternalId: wire.salesAssociateExternalId,
            salesAssociate: wire.salesAssociate.map(SalesAssociateSummary.init(wire:)),
            totalSpent12M: wire.totalSpent12M,
            totalSpentLifetime: wire.totalSpentLifetime,
            numTransactions12M: wire.numTransactions12M,
            firstTransactionAt: wire.firstTransactionAt,
            lastTransactionAt: wire.lastTransactionAt,
            lastInteractionAt: wire.lastInteractionAt,
            preferredChannelRaw: wire.preferredChannel,
            rfmRecency12M: wire.rfmRecency12M,
            rfmFrequency12M: wire.rfmFrequency12M,
            rfmMonetary12M: wire.rfmMonetary12M,
            searchWords: wire.searchWords,
            searchPhones: wire.searchPhones
        )
    }
}

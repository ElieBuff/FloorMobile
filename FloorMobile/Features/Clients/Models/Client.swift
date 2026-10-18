//
//  Client.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// A client of the connected sales associate's store, kept on the device.
///
/// Local-first: the store's clients are loaded in full once, then only what
/// changed (`ClientService`), and read by the views through `@Query`. Every
/// field a list may filter or sort on sits at the top level — a composite
/// attribute's members cannot appear in a predicate. `nonisolated` so the
/// import can run off the main actor.
@Model
nonisolated final class Client {
    @Attribute(.unique) var id: String
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

    /// The associate the client is assigned to, by the external id the
    /// server keys them on — not the id `SalesAssociateSummary.id` carries
    /// elsewhere, hence a field of its own.
    var salesAssociateExternalId: String?
    /// That associate's name, as a display snapshot.
    var salesAssociate: SalesAssociateSummary?

    /// Whole units, as the server stores them.
    var totalSpent12M: Int
    var totalSpentLifetime: Int
    var numTransactions12M: Int
    var firstTransactionAt: Date?
    var lastTransactionAt: Date?
    var lastInteractionAt: Date?

    /// Raw server value (open set, e.g. "EMAIL" / "WHATSAPP"): kept raw.
    var preferredChannelRaw: String?

    var rfmRecency12M: Int?
    var rfmFrequency12M: Int?
    var rfmMonetary12M: Int?

    /// The words the server finds the client by (first name, last name, the
    /// email before its @ — folded, each multi-word value also glued), kept as
    /// received for a future search on the device: nothing reads them yet.
    /// One opaque blob in the store, so no predicate can look inside.
    var searchWords: [String] = []
    /// The client's phone numbers as digits, one entry per number, kept the
    /// same way for a search by phone number.
    var searchPhones: [String] = []

    init(
        id: String,
        externalId: String,
        firstName: String? = nil,
        lastName: String? = nil,
        primaryEmail: String? = nil,
        primaryPhone: String? = nil,
        segment: String? = nil,
        storeCode: String? = nil,
        optinEmail: Bool = false,
        optinPhone: Bool = false,
        optinIM: Bool = false,
        salesAssociateExternalId: String? = nil,
        salesAssociate: SalesAssociateSummary? = nil,
        totalSpent12M: Int = 0,
        totalSpentLifetime: Int = 0,
        numTransactions12M: Int = 0,
        firstTransactionAt: Date? = nil,
        lastTransactionAt: Date? = nil,
        lastInteractionAt: Date? = nil,
        preferredChannelRaw: String? = nil,
        rfmRecency12M: Int? = nil,
        rfmFrequency12M: Int? = nil,
        rfmMonetary12M: Int? = nil,
        searchWords: [String] = [],
        searchPhones: [String] = []
    ) {
        self.id = id
        self.externalId = externalId
        self.firstName = firstName
        self.lastName = lastName
        self.primaryEmail = primaryEmail
        self.primaryPhone = primaryPhone
        self.segment = segment
        self.storeCode = storeCode
        self.optinEmail = optinEmail
        self.optinPhone = optinPhone
        self.optinIM = optinIM
        self.salesAssociateExternalId = salesAssociateExternalId
        self.salesAssociate = salesAssociate
        self.totalSpent12M = totalSpent12M
        self.totalSpentLifetime = totalSpentLifetime
        self.numTransactions12M = numTransactions12M
        self.firstTransactionAt = firstTransactionAt
        self.lastTransactionAt = lastTransactionAt
        self.lastInteractionAt = lastInteractionAt
        self.preferredChannelRaw = preferredChannelRaw
        self.rfmRecency12M = rfmRecency12M
        self.rfmFrequency12M = rfmFrequency12M
        self.rfmMonetary12M = rfmMonetary12M
        self.searchWords = searchWords
        self.searchPhones = searchPhones
    }
}

nonisolated extension Client {

    // MARK: - Display

    /// "Raphaël Van den Berg", "Raphaël", "Van den Berg", or `nil` when the
    /// API sent no name.
    var displayName: String? {
        PersonName.display(first: firstName, last: lastName)
    }

    // MARK: - Search

    /// The clients whose first name, last name, email or phone contains
    /// `query`, case and accents aside — "mart" finds Martinez, "helene"
    /// finds Hélène. A blank query matches everyone.
    ///
    /// A predicate, so the store does the filtering and a list loads only the
    /// matches. `localizedStandardContains` is the comparison iOS itself uses
    /// (Contacts, Spotlight), and the one a SwiftData predicate can express.
    static func matching(_ query: String) -> Predicate<Client> {
        let query = query.trimmingCharacters(in: .whitespaces)
        return #Predicate { client in
            query.isEmpty
                || client.firstName?.localizedStandardContains(query) == true
                || client.lastName?.localizedStandardContains(query) == true
                || client.primaryEmail?.localizedStandardContains(query) == true
                || client.primaryPhone?.localizedStandardContains(query) == true
        }
    }
}

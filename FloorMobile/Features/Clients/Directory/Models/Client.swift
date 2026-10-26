//
//  Client.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// A client of the connected sales associate's store, kept on the device: the
/// card the server sends of the associate's own clients (`ClientWire`), and
/// nothing more — who they are, their store and associate, how to reach them,
/// and the words a future search on the device will read.
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
    /// That store as a display snapshot, for its name. A rename reaches the
    /// device with the client's next change.
    var store: StoreSummary?

    /// The associate the client is assigned to, by the external id the
    /// server keys them on — `salesAssociate` carries the internal one, hence
    /// a field of its own.
    var salesAssociateExternalId: String?
    /// That associate's name, as a display snapshot.
    var salesAssociate: SalesAssociateSummary?

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
        store: StoreSummary? = nil,
        salesAssociateExternalId: String? = nil,
        salesAssociate: SalesAssociateSummary? = nil,
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
        self.store = store
        self.salesAssociateExternalId = salesAssociateExternalId
        self.salesAssociate = salesAssociate
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

//
//  Client.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// A client of the connected sales associate's store, kept on the device: the
/// card the server sends of the associate's own clients (`ClientWire`), and
/// nothing more — who they are, their store and associate, how to reach them
/// and what they agreed to, and the words a future search on the device will
/// read.
///
/// Kept for when the server cannot be reached: the store's clients are loaded
/// in full once, then only what changed (`ClientService`); the Clients tab
/// asks the server first, and reads them — a page at a time (`page`) — only
/// without a connection (decision of 12/11). Every
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
    var store: StoreSnapshot?

    /// The associate the client is assigned to, by the external id the
    /// server keys them on — `salesAssociate` carries the internal one, hence
    /// a field of its own.
    var salesAssociateExternalId: String?
    /// That associate's name, as a display snapshot.
    var salesAssociate: SalesAssociateSnapshot?

    /// The words the server finds the client by (first name, last name, the
    /// email before its @ — folded, each multi-word value also glued), kept as
    /// received for a future search on the device: nothing reads them yet.
    /// One opaque blob in the store, so no predicate can look inside.
    var searchWords: [String] = []
    /// The client's phone numbers as digits, one entry per number, kept the
    /// same way for a search by phone number.
    var searchPhones: [String] = []

    /// The server's own value (`mister`, `misses`, `miss`), as received.
    var salutation: String?
    /// An ISO 639-1 code ("fr", "en", "zh").
    var preferredLanguage: String?
    /// Their main address, as a composite.
    var address: ClientItem.Address?
    /// What they agreed to be reached by, as a composite.
    var optIns: ClientItem.OptIns?

    init(
        id: String,
        externalId: String,
        firstName: String? = nil,
        lastName: String? = nil,
        primaryEmail: String? = nil,
        primaryPhone: String? = nil,
        segment: String? = nil,
        storeCode: String? = nil,
        store: StoreSnapshot? = nil,
        salesAssociateExternalId: String? = nil,
        salesAssociate: SalesAssociateSnapshot? = nil,
        searchWords: [String] = [],
        searchPhones: [String] = [],
        salutation: String? = nil,
        preferredLanguage: String? = nil,
        address: ClientItem.Address? = nil,
        optIns: ClientItem.OptIns? = nil
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
        self.salutation = salutation
        self.preferredLanguage = preferredLanguage
        self.address = address
        self.optIns = optIns
    }
}

nonisolated extension Client {

    // MARK: - Display

    /// "Raphaël Van den Berg", "Raphaël", "Van den Berg", or `nil` when the
    /// API sent no name.
    var displayName: String? {
        PersonName.display(first: firstName, last: lastName)
    }

    // MARK: - Pages

    /// One page of the store's clients, by last name then first name: `size`
    /// of them from `cursor` — an offset into that order, `nil` for the first
    /// page — as cards, like the server's pages, and where the next one
    /// starts: `nil` once a page comes back short. The Clients tab's list
    /// without a connection, through `PagedSearchList`. No filter: the device
    /// does not search (decision of 12/11).
    ///
    /// The id breaks ties between two clients of the same name: without it,
    /// two pages could each take the same one, or neither.
    static func page(
        after cursor: String?, size: Int, in context: ModelContext
    ) throws -> (clients: [ClientItem], next: String?) {
        let offset = cursor.flatMap { Int($0) } ?? 0
        var descriptor = FetchDescriptor<Client>(
            sortBy: [SortDescriptor(\.lastName), SortDescriptor(\.firstName), SortDescriptor(\.id)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = size
        let clients = try context.fetch(descriptor)
        return (clients.map { ClientItem(client: $0) }, clients.count == size ? String(offset + size) : nil)
    }

    // MARK: - Edit

    /// Takes what an edit can change, from the client as the server answered
    /// it (`ClientService.update`): the name, the email, the phone, the
    /// address and the consents. The search's words stay the server's until
    /// the next sync: nothing reads them yet.
    func apply(_ edited: ClientItem) {
        firstName = edited.firstName
        lastName = edited.lastName
        primaryEmail = edited.primaryEmail
        primaryPhone = edited.primaryPhone
        address = edited.address
        optIns = edited.optIns
    }
}

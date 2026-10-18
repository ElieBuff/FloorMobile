//
//  SalesAssociateSummary.swift
//  FloorMobile
//

import Foundation

/// A sales associate embedded in a `@Model` for display: a value snapshot
/// stored as a SwiftData composite attribute (hence `Codable` — for the store,
/// not the network: it comes off the wire as a `SalesAssociateWire`). Its
/// members can't be used in a `@Query` predicate — hoist a field to the
/// model's top level to filter or sort on it.
nonisolated struct SalesAssociateSummary: Codable, Sendable, Equatable {
    var id: String?
    var firstName: String?
    var lastName: String?

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var displayName: String? {
        PersonName.display(first: firstName, last: lastName)
    }

    init(id: String? = nil, firstName: String? = nil, lastName: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
    }

    init(wire: SalesAssociateWire) {
        self.init(id: wire.id, firstName: wire.firstName, lastName: wire.lastName)
    }
}

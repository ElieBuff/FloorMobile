//
//  SalesAssociateSnapshot.swift
//  FloorMobile
//

import Foundation

/// A sales associate embedded in a `@Model` for display: a few of their
/// fields, copied as they were at the last sync, and stored as a SwiftData
/// composite attribute (hence `Codable` — for the store, not the network: it
/// comes off the wire as a `SalesAssociateSnapshotWire`). Its members can't be
/// used in a `@Query` predicate — hoist a field to the model's top level to
/// filter or sort on it.
///
/// Also the associate signed in, as `GET setup` describes them, carried by
/// `AppSession` and kept in `UserDefaults` (`StoredValue.signedInAssociate`).
nonisolated struct SalesAssociateSnapshot: Codable, Sendable, Equatable {
    var id: String?
    var firstName: String?
    var lastName: String?
    /// `"Fr"`, `"En"`… — kept raw, the server may add more; `nil` when they
    /// set none. Read for the associate signed in: the language a dictation
    /// starts in (`TranscriptionLanguage`).
    var preferredLanguage: String?

    init(id: String? = nil, firstName: String? = nil, lastName: String? = nil, preferredLanguage: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.preferredLanguage = preferredLanguage
    }

    init(wire: SalesAssociateSnapshotWire) {
        self.init(
            id: wire.id, firstName: wire.firstName, lastName: wire.lastName,
            preferredLanguage: wire.preferredLanguage
        )
    }
}

nonisolated extension SalesAssociateSnapshot {

    // MARK: - Display

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var displayName: String? {
        PersonName.display(first: firstName, last: lastName)
    }
}

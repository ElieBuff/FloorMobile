//
//  StoreSnapshot.swift
//  FloorMobile
//

import Foundation

/// A store embedded in a `@Model` for display: a few of its fields, copied as
/// they were at the last sync, and stored as a SwiftData composite attribute.
/// Its members can't be used in a `@Query` predicate.
nonisolated struct StoreSnapshot: Codable, Sendable, Equatable {
    var id: String?
    var name: String?
    var storeCode: String?

    init(id: String? = nil, name: String? = nil, storeCode: String? = nil) {
        self.id = id
        self.name = name
        self.storeCode = storeCode
    }

    init(wire: StoreSnapshotWire) {
        self.init(id: wire.id, name: wire.name, storeCode: wire.storeCode)
    }
}

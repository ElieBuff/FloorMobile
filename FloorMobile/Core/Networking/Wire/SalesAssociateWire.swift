//
//  SalesAssociateWire.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a sales associate as Floor endpoints embed them —
/// with an id on agenda items and AI actions, by name alone (`SA`) on clients.
/// A plain struct, like `StoreWire`: no endpoint serves it on its own. Mapped
/// to `SalesAssociateSummary` by `init(wire:)`.
nonisolated struct SalesAssociateWire: Decodable, Sendable {
    var id: String?
    var firstName: String?
    var lastName: String?
}

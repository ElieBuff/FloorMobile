//
//  SalesAssociateSnapshotWire.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a sales associate as Floor endpoints embed them —
/// the shared projection (`SALES_ASSOCIATE_SUMMARY_SELECT`) on agenda items,
/// AI actions, clients (`SA`) and a client's details (`client/{id}`). The
/// projection also carries the associate's `preferredLanguage`, which the app
/// does not read here. A plain struct, like `StoreSnapshotWire`: no endpoint
/// serves it on its own. Mapped to `SalesAssociateSnapshot` by `init(wire:)`,
/// and flattened into a client's card by `ClientItem.init(wire:)`.
nonisolated struct SalesAssociateSnapshotWire: Decodable, Sendable {
    var id: String?
    /// Read from a client's details only, for their card
    /// (`ClientItem.salesAssociateExternalId`): a client in a list has it
    /// flat (`SAExternalId`).
    var externalId: String?
    var firstName: String?
    var lastName: String?
}

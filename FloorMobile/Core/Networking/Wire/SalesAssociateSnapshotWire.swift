//
//  SalesAssociateSnapshotWire.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a sales associate as Floor endpoints embed them —
/// the shared projection (`SALES_ASSOCIATE_SNAPSHOT_SELECT`) on agenda items,
/// AI actions, clients (`SA`), a client's details (`client/{id}`) and the
/// associate signed in (`GET setup`, `SetupWire.SalesAssociate`). A plain
/// struct, like `StoreSnapshotWire`: no endpoint serves it on its own. Mapped
/// to `SalesAssociateSnapshot` by `init(wire:)`, and flattened into a client's
/// card by `ClientItem.init(wire:)`.
nonisolated struct SalesAssociateSnapshotWire: Decodable, Sendable {
    var id: String?
    /// Read from a client's details only, for their card
    /// (`ClientItem.salesAssociateExternalId`): a client in a list has it
    /// flat (`SAExternalId`).
    var externalId: String?
    var firstName: String?
    var lastName: String?
    /// `"Fr"`, `"En"`… — kept raw; `nil` when the associate set none.
    var preferredLanguage: String?
}

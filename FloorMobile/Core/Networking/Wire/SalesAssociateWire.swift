//
//  SalesAssociateWire.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a sales associate as Floor endpoints embed them —
/// the shared projection (`SALES_ASSOCIATE_SUMMARY_SELECT`) on agenda items,
/// AI actions and clients (`SA`): its id and its name. The projection also
/// carries the associate's `externalId`, which the app does not read: a
/// client has it flat (`SAExternalId`). A plain struct, like `StoreWire`: no
/// endpoint serves it on its own. Mapped to `SalesAssociateSummary` by
/// `init(wire:)`.
nonisolated struct SalesAssociateWire: Decodable, Sendable {
    var id: String?
    var firstName: String?
    var lastName: String?
}

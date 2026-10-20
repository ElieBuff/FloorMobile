//
//  ClientSummaryWire.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a client as Floor endpoints embed them in another
/// object — an agenda item, an AI action, a recent client
/// (`RecentClientWire`). A plain struct, like `StoreWire`: no endpoint serves
/// it on its own. Mapped to `ClientSummary` by `init(wire:)`.
nonisolated struct ClientSummaryWire: Decodable, Sendable {
    var id: String?
    var externalId: String?
    var firstName: String?
    var lastName: String?
    var segment: String?
    var metrics: Metrics?

    struct Metrics: Decodable, Sendable {
        var totalSpent12M: Decimal?
        var totalSpentLifetime: Decimal?
    }
}

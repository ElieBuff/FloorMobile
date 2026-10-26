//
//  RecentClient.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// A client the connected sales associate opened lately: one entry of their
/// recent clients.
///
/// The server keeps the list — which clients, in which order, how many — and
/// the device keeps its copy: refreshed whole at launch, and again after every
/// opening of a client's profile, from the server's list (`ClientService`).
/// The device never trims it on its own. The store keeps no order: read the
/// list sorted on `lastViewedAt`, latest first — the server's own order.
/// Nothing reads it yet: the screen that shows it is still to design.
///
/// The client is an embedded display snapshot, like an agenda item's, and not
/// a relationship to `Client`: it may be any client of the brand, so not one
/// the device keeps, and the client sync replaces its rows in place, which a
/// relationship would not survive. `id` sits at the top level as the unique
/// key the refresh upserts on, `lastViewedAt` as the sort key.
@Model
nonisolated final class RecentClient: Syncable {
    /// The client's id — one entry per client.
    @Attribute(.unique) var id: String
    /// Per-sync generation marker (mark-and-sweep); not from the API.
    var syncToken: String = ""
    /// When the associate last opened this client's profile, by the server's
    /// clock.
    var lastViewedAt: Date
    var client: ClientSummary

    init(id: String, lastViewedAt: Date, client: ClientSummary) {
        self.id = id
        self.lastViewedAt = lastViewedAt
        self.client = client
    }
}

nonisolated extension RecentClient {

    // MARK: - Sync

    /// Rows the latest refresh did not return (see `Syncable`).
    static func stale(token: String) -> Predicate<RecentClient> {
        #Predicate { $0.syncToken != token }
    }
}

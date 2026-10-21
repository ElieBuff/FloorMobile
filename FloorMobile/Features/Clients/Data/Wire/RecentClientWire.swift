//
//  RecentClientWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `RecentClient`: what `client/recent` serves, and what
/// recording a view (`client/{id}/view`) answers — the same list. Read-only.
nonisolated enum RecentClientWire {
    /// The whole list, `{ items }`: the associate's last clients, each once,
    /// the latest view first. Not a `CursorPage`: the route has no cursor, and
    /// sends no `hasMore`.
    struct List: Decodable, Sendable {
        var items: [Response]
    }

    /// One recent client: which client, when the associate last opened their
    /// profile, and the client embedded as an agenda item embeds them
    /// (`ClientSummaryWire`). `clientId` is the row's own column: the key,
    /// which the embedded client's optional `id` cannot be.
    struct Response: Decodable, Sendable {
        var clientId: String
        var lastViewedAt: Date
        var client: ClientSummaryWire
    }
}

nonisolated extension RecentClient {
    /// Maps the wire format into the local model: `clientId` keys it, and the
    /// embedded client becomes its snapshot.
    convenience init(wire: RecentClientWire.Response) {
        self.init(
            id: wire.clientId,
            lastViewedAt: wire.lastViewedAt,
            client: ClientSummary(wire: wire.client)
        )
    }
}

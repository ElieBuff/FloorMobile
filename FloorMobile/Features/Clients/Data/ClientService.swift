//
//  ClientService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// The Clients feature's data service: keeps the connected associate's store
/// clients in SwiftData. A `@ModelActor` so the import runs off the main actor
/// on a private, actor-owned context.
///
/// Not a full refresh like the agenda's: a store holds thousands of clients,
/// so they are loaded in full once, then only what changed. That is why a page
/// never sweeps what it does not carry — what is missing from a delta is
/// unchanged, not gone. What is gone is found by `pruneDeparted(using:)`.
@ModelActor
actor ClientService {

    /// Brings the store's clients up to date: pages through `client/sync` from
    /// the stored cursor (from zero without one), upserting each page as it
    /// arrives.
    ///
    /// The cursor is stored only once the pass is complete, after its last
    /// page is saved. A pass cut short starts again from the previous cursor —
    /// the pages it already wrote are simply written again, which the server
    /// allows for: a client changed during a pass may come twice, never not at
    /// all. And a stored cursor always means a pass went through.
    func synchronize(using client: APIClient, cursor: StoredValue<String>) async throws {
        var after = cursor.get()
        while true {
            let page: CursorPage<ClientWire.Response> = try await client.send(.clientSync(after: after))
            try modelContext.upsert(page.items, make: Client.init(wire:))
            // Never null on this route, the last page included: that last one
            // is what the next sync starts from.
            guard let next = page.nextCursor else { return }
            guard page.hasMore else {
                cursor.set(next)
                return
            }
            after = next
        }
    }

    /// Deletes the clients the store no longer has — moved to another store,
    /// or removed — which a delta cannot report: it only carries what is
    /// there.
    ///
    /// The difference is taken in memory rather than in a predicate: a store's
    /// ids run to tens of thousands, past what SQLite accepts in one `IN`.
    func pruneDeparted(using client: APIClient) async throws {
        let store: ClientWire.StoreIDs = try await client.send(.storeClientIDs)
        let kept = Set(store.ids)

        var local = FetchDescriptor<Client>()
        local.propertiesToFetch = [\.id]
        let departed = try modelContext.fetch(local).map(\.id).filter { !kept.contains($0) }
        guard !departed.isEmpty else { return }

        for start in stride(from: 0, to: departed.count, by: Self.deleteBatchSize) {
            let batch = Array(departed[start..<min(start + Self.deleteBatchSize, departed.count)])
            try modelContext.delete(model: Client.self, where: #Predicate { batch.contains($0.id) })
        }
        try modelContext.save()
    }

    /// One page of the associate's own clients matching `query`, closest
    /// first, and where the next page starts — `nil` once there is none.
    ///
    /// Straight from the server and not stored, like the brand search: the
    /// device already keeps the store's clients, and this is only what the
    /// server found among them, typos and all.
    func searchMyClients(
        _ query: String,
        after cursor: String? = nil,
        using client: APIClient
    ) async throws -> (clients: [MyClient], nextCursor: String?) {
        let page: CursorPage<MyClientWire.Response> = try await client.send(
            .searchMyClients(query, after: cursor)
        )
        return (page.items.map(MyClient.init(wire:)), page.hasMore ? page.nextCursor : nil)
    }

    /// One page of the brand's clients matching `query`, closest first, and
    /// where the next page starts — `nil` once there is none.
    ///
    /// Straight from the server and not stored: the brand runs to far more
    /// clients than a device should hold, and they are not this store's.
    func searchBrand(
        _ query: String,
        after cursor: String? = nil,
        using client: APIClient
    ) async throws -> (clients: [BrandClient], nextCursor: String?) {
        let page: CursorPage<BrandClientWire.Response> = try await client.send(
            .searchBrandClients(query, after: cursor)
        )
        return (page.items.map(BrandClient.init(wire:)), page.hasMore ? page.nextCursor : nil)
    }

    /// Well under SQLite's limit on bound variables per statement.
    private static let deleteBatchSize = 500
}

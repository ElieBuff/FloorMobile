//
//  ClientService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// The Clients feature's data service: keeps the connected associate's store
/// clients and their recent clients in SwiftData, and asks for a client's
/// profile without keeping it. A `@ModelActor` so the import runs off the main
/// actor on a private, actor-owned context.
///
/// The store's clients are not refreshed in full like the agenda's: a store
/// holds thousands of them, so they are loaded in full once, then only what
/// changed. That is why a page never sweeps what it does not carry — what is
/// missing from a delta is unchanged, not gone. What is gone is found by
/// `pruneDeparted(using:)`. The recent clients are refreshed in full: a few
/// of them, in the server's order, which `lastViewedAt` carries.
@ModelActor
actor ClientService {

    /// Well under SQLite's limit on bound variables per statement.
    private static let deleteBatchSize = 500

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

    /// One page of the clients `scope` holds matching `query` — or, without
    /// it, in the sort's order — and where the next page starts: `nil` once
    /// `hasMore` says there is none, whatever cursor the last page carries.
    ///
    /// Straight from the server and not stored: the device already keeps the
    /// store's clients ("My Clients" is what the server found among them,
    /// typos and all), and the brand runs to far more clients than a device
    /// should hold. See `Endpoint.searchClients` for what each scope sends.
    func searchClients(
        _ query: String?,
        in scope: ClientSearchScope,
        options: ClientSearchOptions = ClientSearchOptions(),
        after cursor: String? = nil,
        using client: APIClient
    ) async throws -> (clients: [ClientItem], nextCursor: String?) {
        let page: CursorPage<ClientWire.Response> = try await client.send(
            .searchClients(query, in: scope, options: options, after: cursor)
        )
        return (page.items.map(ClientItem.init(wire:)), page.hasMore ? page.nextCursor : nil)
    }

    /// How many clients `searchClients` would list for the same text, scope
    /// and filters — "My Clients"' "Apply (n)". Straight from the server, like
    /// a search. A refusal (409 `filters_changed`, 503 `search_timeout`) is
    /// thrown as `AppError.server(statusCode:)`, its body dropped, and a
    /// network failure as `AppError.network`, for the caller to show. See
    /// `Endpoint.countClients`.
    func countClients(
        _ query: String?,
        in scope: ClientSearchScope,
        filters: [ClientFilterChoice] = [],
        using client: APIClient
    ) async throws -> Int {
        let count: ClientWire.Count = try await client.send(.countClients(query, in: scope, filters: filters))
        return count.total
    }

    /// One client's profile, everything the server holds on them.
    ///
    /// Straight from the server and not stored, like a search result: any
    /// client of the brand can be opened, while the device keeps only its
    /// store's.
    func profile(id: String, using client: APIClient) async throws -> ClientProfile {
        let wire: ClientProfileWire.Response = try await client.send(.clientProfile(id: id))
        return ClientProfile(wire: wire)
    }

    /// Asks for the associate's recent clients and keeps them, at launch.
    func synchronizeRecent(using client: APIClient) async throws {
        let list: RecentClientWire.List = try await client.send(.recentClients)
        try await replaceRecent(with: list)
    }

    /// Records that the associate opened this client's profile, and keeps the
    /// recent clients the server answers with, as they now stand — this
    /// client first, moved up if it was already there. No second call, and a
    /// list that holds the view it follows.
    ///
    /// A view the server refuses (404) or that never leaves (offline, see
    /// `Endpoint.recordClientView`) throws before anything is written: the
    /// list stays as it was.
    func recordView(of id: String, using client: APIClient) async throws {
        let list: RecentClientWire.List = try await client.send(.recordClientView(id: id))
        try await replaceRecent(with: list)
    }

    /// Replaces the device's recent clients with `list`, by mark-and-sweep
    /// like the AI actions: the server alone orders and bounds it, so the
    /// device keeps exactly what it sends — whichever route sent it.
    private func replaceRecent(with list: RecentClientWire.List) async throws {
        try await modelContext.refresh(from: { list.items }, make: RecentClient.init(wire:))
    }
}

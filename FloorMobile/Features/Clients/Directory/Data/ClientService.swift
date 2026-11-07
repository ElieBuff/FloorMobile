//
//  ClientService.swift
//  FloorMobile
//

import Foundation
import SwiftData
import os

/// The Clients feature's data service: keeps the connected associate's store
/// clients in SwiftData, and asks for the three parts of a client's profile —
/// their details, their AI summary, their timeline — without keeping them. A
/// `@ModelActor` so the import runs off the main actor on a private,
/// actor-owned context.
///
/// The store's clients are not refreshed in full like the agenda's: a store
/// holds thousands of them, so they are loaded in full once, then only what
/// changed. That is why a page never sweeps what it does not carry — what is
/// missing from a delta is unchanged, not gone. What is gone is found by
/// `pruneDeparted(using:)`.
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
    /// and filters — the total "Filter" shows under its sentence. Straight
    /// from the server, like a search. A refusal (409 `filters_changed`, 503
    /// `search_timeout`) is thrown as `AppError.server(statusCode:)`, its
    /// body dropped, and a network failure as `AppError.network`, for the
    /// caller to show. See `Endpoint.countClients`.
    func countClients(
        _ query: String?,
        in scope: ClientSearchScope,
        filters: [ClientFilterChoice] = [],
        using client: APIClient
    ) async throws -> Int {
        let count: ClientWire.Count = try await client.send(.countClients(query, in: scope, filters: filters))
        return count.total
    }

    /// The filters a sentence describes, as the server reads it — the sentence
    /// of "Filter"'s field. Straight from the server, kept nowhere: the caller
    /// shows the items, and sends back with the search the ones still there.
    /// A failure — 502, intelligence failed or did not answer within the BFF's
    /// 80 s, whatever the sentence; 400, a sentence out of bounds — is thrown
    /// as `AppError.server(statusCode:)`, a network failure as
    /// `AppError.network`. See `Endpoint.clientTextFilters`.
    func filterItems(from sentence: String, using client: APIClient) async throws -> ClientFilterItems {
        let wire: ClientFilterItemsWire.Response = try await client.send(.clientTextFilters(sentence))
        return ClientFilterItems(wire: wire)
    }

    /// Who one client is: the first part of their profile (`ClientProfile`),
    /// bounded — their purchases and messages are `timeline(id:using:)`'s.
    ///
    /// Straight from the server and not stored, like a search result: any
    /// client of the brand can be opened, while the device keeps only its
    /// store's. So are the two other parts. A client the tenant does not have
    /// is thrown as `AppError.server(statusCode: 404)`, a network failure as
    /// `AppError.network`. See `Endpoint.clientDetails`.
    func details(id: String, using client: APIClient) async throws -> ClientItem {
        let wire: ClientDetailsWire.Response = try await client.send(.clientDetails(id: id))
        return ClientItem(wire: wire)
    }

    /// Sends what `edited` changes from `original` (`ClientDetailsWire.Request`)
    /// and returns the client as the server now has them. The signature goes
    /// with changed consents, which the server refuses without one
    /// (`AppError.server(statusCode: 422)`); not their client is a 403, a
    /// network failure `AppError.network`, and a failure writes nothing. A
    /// network failure first reads the client again: when the server holds
    /// the edit all the same, its answer only was lost, and the save stands.
    ///
    /// The device's copy follows: the `Client` of this id, when the store
    /// keeps one, takes what an edit changes (`Client.apply`) — none is
    /// created for a client the store does not keep. A copy that cannot be
    /// written is logged, not thrown: the server has the edit, and the next
    /// sync brings it.
    func update(
        _ edited: ClientItem,
        from original: ClientItem,
        signature: ClientSignature?,
        using client: APIClient
    ) async throws -> ClientItem {
        let body = ClientDetailsWire.Request(edited: edited, original: original, signature: signature)
        let saved: ClientItem
        do {
            let wire: ClientDetailsWire.Response = try await client.send(.updateClient(id: original.id, body: body))
            saved = ClientItem(wire: wire)
        } catch let error as AppError {
            // A network failure may come after the server's write: read the client
            // again rather than send again, which would record the signature twice.
            guard case .network = error,
                  let current = try? await details(id: edited.id, using: client),
                  !edited.hasChanges(from: current) else { throw error }
            saved = current
        }
        do {
            let id = saved.id
            let kept = try modelContext.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.id == id }))
            if let stored = kept.first {
                stored.apply(saved)
                try modelContext.save()
            }
        } catch {
            AppLog.sync.error("Keeping an edited client failed: \(error.localizedDescription, privacy: .public)")
        }
        return saved
    }

    /// One client's AI summary, as the server has it or computes it now — a
    /// few seconds then, 40 s at most. A summary that could not be computed is
    /// thrown as `AppError.server(statusCode: 502)`, an unknown client as a
    /// 404, a network failure as `AppError.network`. See
    /// `Endpoint.clientSummary`.
    func summary(id: String, using client: APIClient) async throws -> ClientSummary {
        let wire: ClientSummaryWire.Response = try await client.send(.clientSummary(id: id))
        return ClientSummary(wire: wire)
    }

    /// One client's timeline: what is planned with them, then what happened.
    /// An unknown client is thrown as `AppError.server(statusCode: 404)`, a
    /// network failure as `AppError.network`. See `Endpoint.clientTimeline`.
    func timeline(id: String, using client: APIClient) async throws -> ClientTimeline {
        let wire: ClientTimelineWire.Response = try await client.send(.clientTimeline(id: id))
        return ClientTimeline(wire: wire)
    }

    /// Records that the associate opened this client's profile, for their
    /// recent clients, which the server keeps. The device keeps nothing: the
    /// list the server answers with is not read. A view the server refuses
    /// (404) or that never leaves (offline, see `Endpoint.recordClientView`)
    /// throws.
    func recordView(of id: String, using client: APIClient) async throws {
        try await client.send(.recordClientView(id: id))
    }
}

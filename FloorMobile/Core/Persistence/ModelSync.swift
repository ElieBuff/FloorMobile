//
//  ModelSync.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// A persistent model kept in sync with the server via full-refresh
/// reconciliation (mark-and-sweep): its rows carry a per-sync generation
/// marker. `nonisolated` so it matches the `nonisolated` `@Model` classes (a
/// MainActor-isolated protocol would isolate `syncToken` and break SwiftData's
/// key-path generation).
///
/// `stale(token:)` is required (not defaulted) because `#Predicate` can't be
/// formed over a generic type, so each concrete model builds its own next to
/// `syncToken`.
nonisolated protocol Syncable: PersistentModel {
    var syncToken: String { get set }
    /// Matches the rows *not* stamped with `token` — the ones the last refresh
    /// did not return.
    static func stale(token: String) -> Predicate<Self>
}

extension ModelContext {
    /// Inserts (upserts) a batch and saves. Upsert relies on the model's
    /// identity key being `@Attribute(.unique)`, so re-inserting a known id
    /// replaces the stored row in place instead of duplicating it.
    func upsert<Incoming, Model: PersistentModel>(
        _ items: [Incoming],
        make: (Incoming) -> Model
    ) throws {
        for item in items {
            insert(make(item))
        }
        try save()
    }

    /// Batch-deletes every row matching `predicate`, then saves.
    func sweep<Model: PersistentModel>(_ type: Model.Type, matching predicate: Predicate<Model>) throws {
        try delete(model: Model.self, where: predicate)
        try save()
    }

    /// Full-refreshes a model from a paginated source via mark-and-sweep:
    /// mints a fresh token, pages through the cursor (persisting each page as it
    /// arrives, stamped by `make`), then `sweep`s whatever still bears an older
    /// token. Callers supply only *what to fetch*, *how to map+stamp*, and *how
    /// to sweep* — the token, the loop and the ordering live here.
    func refresh<Item: Decodable & Sendable, Model: PersistentModel & Syncable>(
        paginatedBy fetch: (_ cursor: String?) async throws -> CursorPage<Item>,
        make: (Item) -> Model
    ) async throws {
        let token = UUID().uuidString
        var cursor: String?
        repeat {
            let page = try await fetch(cursor)
            try upsert(page.items) { item in
                let model = make(item)
                model.syncToken = token
                return model
            }
            cursor = page.hasMore ? page.nextCursor : nil
        } while cursor != nil
        try sweep(Model.self, matching: Model.stale(token: token))
    }

    /// Convenience for a non-paginated endpoint that returns the full set at
    /// once. Same mark-and-sweep guarantees as the paginated overload.
    func refresh<Item: Decodable & Sendable, Model: PersistentModel & Syncable>(
        from fetch: () async throws -> [Item],
        make: (Item) -> Model
    ) async throws {
        try await refresh(
            paginatedBy: { _ in CursorPage(items: try await fetch(), hasMore: false, nextCursor: nil) },
            make: make
        )
    }
}

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

/// A persistent model whose stored set is replaced whole — and only when it
/// changed (`ModelContext.replace(with:order:)`). `hasSameContent(as:)` lives
/// beside the model's stored fields, so a field added there is not forgotten
/// here.
nonisolated protocol ContentComparable: PersistentModel {
    /// Whether `other` holds the same content, every stored field compared.
    func hasSameContent(as other: Self) -> Bool
}

extension ModelContext {
    /// Inserts (upserts) a batch and saves. Upsert relies on the model's
    /// identity key being `@Attribute(.unique)`, so re-inserting a known id
    /// replaces the stored row in place instead of duplicating it.
    nonisolated func upsert<Incoming, Model: PersistentModel>(
        _ items: [Incoming],
        make: (Incoming) -> Model
    ) throws {
        for item in items {
            insert(make(item))
        }
        try save()
    }

    /// Stores one row the server just handed back — the answer to a write, not
    /// a page of a refresh.
    ///
    /// Stamped with a token of its own. A refresh finishing in the same breath
    /// could still sweep it — it bears no token that refresh minted — but the
    /// server now has the row, so the next refresh brings it back.
    nonisolated func store<Item, Model: PersistentModel & Syncable>(
        _ item: Item,
        as make: (Item) -> Model
    ) throws {
        try upsert([item]) { incoming in
            let model = make(incoming)
            model.syncToken = UUID().uuidString
            return model
        }
    }

    /// Replaces every stored `Model` with `incoming`, a set the server sends
    /// whole — but only when the two differ. Returns whether it wrote.
    ///
    /// `incoming` comes in `order`, the order the stored side is read in, so
    /// the two compare row by row: a reordering is a change. An unchanged set
    /// costs one fetch and no write, which matters for what is fetched at
    /// every launch and nearly never changes.
    ///
    /// No mark-and-sweep token, unlike `refresh`: that protects data arriving
    /// in pages, where deleting first would empty the store if a page failed.
    /// This set is complete in memory before anything is touched. Deleted row
    /// by row rather than with `delete(model:)`: a batch delete reaches the
    /// store at once, and a reader landing before the save would see an empty
    /// list; per-object deletes wait for the save.
    @discardableResult
    nonisolated func replace<Model: ContentComparable>(
        with incoming: [Model],
        order: SortDescriptor<Model>
    ) throws -> Bool {
        let stored = try fetch(FetchDescriptor<Model>(sortBy: [order]))
        let unchanged = stored.count == incoming.count
            && zip(stored, incoming).allSatisfy { $0.hasSameContent(as: $1) }
        guard !unchanged else { return false }

        for model in stored {
            delete(model)
        }
        for model in incoming {
            insert(model)
        }
        try save()
        return true
    }

    /// Batch-deletes every row matching `predicate`, then saves.
    nonisolated func sweep<Model: PersistentModel>(_ type: Model.Type, matching predicate: Predicate<Model>) throws {
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
        make: (Item) -> Model,
        isolation: isolated (any Actor)? = #isolation
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
        make: (Item) -> Model,
        isolation: isolated (any Actor)? = #isolation
    ) async throws {
        try await refresh(
            paginatedBy: { _ in CursorPage(items: try await fetch(), hasMore: false, nextCursor: nil) },
            make: make,
            isolation: isolation
        )
    }
}

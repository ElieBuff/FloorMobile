//
//  SetupService.swift
//  FloorMobile
//

import Foundation
import SwiftData
import os

/// Keeps the app's configuration — what `GET setup` serves: the field
/// vocabulary (`EnumValue`) and the tenant's "My Clients" filters
/// (`ClientFilter`) in SwiftData, the associate's language in `LocalStore`. A
/// `@ModelActor`, like the other services, so its writes run off the main
/// actor.
@ModelActor
actor SetupService {

    /// Asks for the configuration and saves each block in place of the stored
    /// one — but only when the two actually differ.
    ///
    /// The configuration is identical from one launch to the next nearly every
    /// time, and this sync is what holds the first frame back: `RootView` keeps
    /// the loading screen up until it returns. Rewriting it unconditionally
    /// meant deleting and re-inserting every row at each launch, and having the
    /// main context merge that whole change set, right as the tab tree was
    /// being built. An unchanged block costs one fetch and no write.
    ///
    /// No mark-and-sweep token here, unlike the other services: that machinery
    /// protects data arriving in pages, where deleting first would leave the
    /// store empty if a page failed. This payload is small and lands whole, so
    /// the complete set is in memory before anything is touched — and a failed
    /// request leaves the previous configuration untouched.
    ///
    /// Deleted row by row rather than with `delete(model:)`: a batch delete
    /// reaches the store immediately, and a reader landing between it and the
    /// save would see an empty list. Per-object deletes are held until the
    /// save, so readers go straight from the old values to the new ones.
    ///
    /// What describes the associate is a few single values, kept in
    /// `localStore` rather than in SwiftData — wiped with the store. A
    /// parameter, like `ClientService`'s cursor, so a test passes one held in
    /// memory.
    func synchronize(using client: APIClient, localStore: LocalStore) async throws {
        let setup: SetupWire.Response = try await client.send(.setup())
        try saveVocabulary(setup.enums)
        try saveFilters(setup.clients.filters)
        saveSalesAssociate(setup.salesAssociate, in: localStore)
    }

    // MARK: - Sales associate

    /// Keeps what the server says of the connected associate. A missing
    /// language clears the stored one: the associate no longer has one.
    private func saveSalesAssociate(_ salesAssociate: SetupWire.SalesAssociate, in localStore: LocalStore) {
        localStore.preferredLanguage.set(salesAssociate.preferredLanguage)
    }

    // MARK: - Vocabulary

    private func saveVocabulary(_ payload: EnumsWire.Response) throws {
        let rows = EnumsWire.rows(from: payload)

        let stored = try modelContext.fetch(
            FetchDescriptor<EnumValue>(sortBy: [SortDescriptor(\.id, order: .forward)])
        )
        // Logged, not silent: "the launch wrote nothing" is the whole point of
        // the comparison, and it is otherwise invisible from the outside.
        guard Self.differs(stored: stored, from: rows) else {
            AppLog.sync.debug(
                "Vocabulary unchanged (\(rows.count, privacy: .public) values), store left alone"
            )
            return
        }
        AppLog.sync.debug(
            "Vocabulary changed: \(stored.count, privacy: .public) stored → \(rows.count, privacy: .public) served, rewriting"
        )

        for value in stored {
            modelContext.delete(value)
        }
        for row in rows {
            modelContext.insert(EnumValue(wire: row))
        }
        try modelContext.save()
    }

    /// Whether the served vocabulary differs from the stored one.
    ///
    /// Compared on the identity *and* the rank of every row: `rank` carries the
    /// order the server listed a field's values in, which is the order the
    /// pickers show, so a reordering is a real change even when the set of
    /// values is the same.
    ///
    /// Both sides are put in `id` order to compare like with like — `rows` is
    /// flattened in (entity, field) order, which is not the same thing.
    private static func differs(stored: [EnumValue], from rows: [EnumsWire.Row]) -> Bool {
        guard stored.count == rows.count else { return true }
        let incoming = rows
            .map {
                (
                    id: EnumValue.identifier(entityName: $0.entityName, field: $0.field, value: $0.value),
                    rank: $0.rank
                )
            }
            .sorted { $0.id < $1.id }
        return zip(stored, incoming).contains { $0.id != $1.id || $0.rank != $1.rank }
    }

    // MARK: - Client filters

    /// The same way as the vocabulary: compared first, rewritten only when
    /// something changed, logged either way.
    private func saveFilters(_ filters: [ClientFilterWire.Response]) throws {
        let incoming = filters.enumerated().map { ClientFilter(wire: $1, rank: $0) }
        let stored = try modelContext.fetch(
            FetchDescriptor<ClientFilter>(sortBy: [SortDescriptor(\.rank, order: .forward)])
        )
        guard Self.differs(stored: stored, from: incoming) else {
            AppLog.sync.debug(
                "Client filters unchanged (\(incoming.count, privacy: .public) filters), store left alone"
            )
            return
        }
        AppLog.sync.debug(
            "Client filters changed: \(stored.count, privacy: .public) stored → \(incoming.count, privacy: .public) served, rewriting"
        )

        for filter in stored {
            modelContext.delete(filter)
        }
        for filter in incoming {
            modelContext.insert(filter)
        }
        try modelContext.save()
    }

    /// Whether the served filters differ from the stored ones, both in rank
    /// order — the order is the screen's, so a reordering is a change. What
    /// "the same filter" means is the model's (`ClientFilter.hasSameContent`).
    private static func differs(stored: [ClientFilter], from incoming: [ClientFilter]) -> Bool {
        guard stored.count == incoming.count else { return true }
        return zip(stored, incoming).contains { !$0.hasSameContent(as: $1) }
    }
}

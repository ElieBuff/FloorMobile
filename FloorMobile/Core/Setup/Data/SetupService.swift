//
//  SetupService.swift
//  FloorMobile
//

import Foundation
import SwiftData
import os

/// Keeps the app's configuration — what `GET setup` serves: the field
/// vocabulary (`EnumValue`) and the tenant's "My Clients" filters and sorts
/// (`ClientFilter`, `ClientSort`) in SwiftData — and hands back the associate
/// signed in and their store, which `AppSession` carries. A `@ModelActor`,
/// like the other services, so its writes run off the main actor.
@ModelActor
actor SetupService {

    /// Asks for the configuration and saves each block in place of the stored
    /// one — only when it changed (`ModelContext.replace`).
    ///
    /// The configuration is identical from one launch to the next nearly every
    /// time, and this sync is what holds the first frame back: `RootView` keeps
    /// the loading screen up until it returns. An unchanged block costs one
    /// fetch and no write. A failed request leaves the previous configuration
    /// untouched: nothing is replaced before the whole of it is in hand.
    ///
    /// Returns the associate signed in — their language included — and their
    /// store, for the session to carry; `nil` when the server sent no
    /// associate.
    @discardableResult
    func synchronize(using client: APIClient) async throws -> (associate: SalesAssociateSnapshot, store: StoreSnapshot?)? {
        let setup: SetupWire.Response = try await client.send(.setup())
        try saveVocabulary(setup.enums)
        try saveFilters(setup.clients.filters)
        try saveSorts(setup.clients.sorts)
        return setup.salesAssociate.map {
            (SalesAssociateSnapshot(wire: $0.snapshot), $0.primaryStore.map(StoreSnapshot.init(wire:)))
        }
    }

    // MARK: - Blocks

    /// In `id` order, the order the stored side is read in: the rows come
    /// flattened by entity and field, which is not the same thing.
    private func saveVocabulary(_ payload: EnumsWire.Response) throws {
        let values = EnumsWire.rows(from: payload).map(EnumValue.init(wire:)).sorted { $0.id < $1.id }
        let wrote = try modelContext.replace(with: values, order: SortDescriptor(\.id))
        Self.log("Vocabulary", count: values.count, wrote: wrote)
    }

    /// The filters' rank is their place in the block.
    private func saveFilters(_ filters: [ClientFilterWire.Response]) throws {
        let incoming = filters.enumerated().map { ClientFilter(wire: $1, rank: $0) }
        let wrote = try modelContext.replace(with: incoming, order: SortDescriptor(\.rank))
        Self.log("Client filters", count: incoming.count, wrote: wrote)
    }

    /// The sorts' rank is the server's `position`, whatever order the block
    /// lists them in.
    private func saveSorts(_ sorts: [ClientSortWire.Response]) throws {
        let incoming = sorts.map(ClientSort.init(wire:)).sorted { $0.rank < $1.rank }
        let wrote = try modelContext.replace(with: incoming, order: SortDescriptor(\.rank))
        Self.log("Client sorts", count: incoming.count, wrote: wrote)
    }

    /// Logged, not silent: "the launch wrote nothing" is the point of the
    /// comparison, and it is otherwise invisible from the outside.
    private static func log(_ block: String, count: Int, wrote: Bool) {
        AppLog.sync.debug(
            "\(block, privacy: .public): \(wrote ? "changed, rewritten" : "unchanged, store left alone", privacy: .public) (\(count, privacy: .public) served)"
        )
    }
}

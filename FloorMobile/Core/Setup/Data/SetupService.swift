//
//  SetupService.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// Keeps the app's configuration — what `GET setup` serves: the field
/// vocabulary (`EnumValue`), the tenant's "My Clients" filters and sorts
/// (`ClientFilter`, `ClientSort`) and the brand's segments (`ClientSegment`)
/// in SwiftData — and hands back the associate signed in and their store,
/// which `AppSession` carries. A `@ModelActor`, like the other services, so
/// its writes run off the main actor.
@ModelActor
actor SetupService {

    /// Asks for the configuration and saves each block in place of the stored
    /// one, every time (`ModelContext.replace`).
    ///
    /// This sync holds the first frame back: `RootView` keeps the loading
    /// screen up until it returns. Rewriting the whole configuration costs a
    /// few milliseconds (3 ms for its 35 rows, measured 15/11), next to the
    /// request itself. A failed request leaves the previous configuration
    /// untouched: nothing is replaced before the whole of it is in hand.
    ///
    /// Returns the associate signed in — their language included — and their
    /// store, for the session to carry; `nil` when the server sent no
    /// associate.
    @discardableResult
    func synchronize(using client: APIClient) async throws -> (associate: SalesAssociateSnapshot, store: StoreSnapshot?)? {
        let setup: SetupWire.Response = try await client.send(.setup())
        try saveVocabulary(setup.enums)
        try saveFilters(setup.clientConfiguration.filters)
        try saveSorts(setup.clientConfiguration.sorts)
        try saveSegments(setup.clientConfiguration.segments)
        return setup.salesAssociate.map {
            (SalesAssociateSnapshot(wire: $0.snapshot), $0.primaryStore.map(StoreSnapshot.init(wire:)))
        }
    }

    // MARK: - Blocks

    private func saveVocabulary(_ payload: EnumsWire.Response) throws {
        try modelContext.replace(with: EnumsWire.rows(from: payload).map(EnumValue.init(wire:)))
    }

    /// The filters' rank is their place in the block.
    private func saveFilters(_ filters: [ClientFilterWire.Response]) throws {
        try modelContext.replace(with: filters.enumerated().map { ClientFilter(wire: $1, rank: $0) })
    }

    /// The sorts' rank is the server's `position`, whatever order the block
    /// lists them in.
    private func saveSorts(_ sorts: [ClientSortWire.Response]) throws {
        try modelContext.replace(with: sorts.map(ClientSort.init(wire:)))
    }

    /// The segments' rank is their place in the block, the brand's order.
    private func saveSegments(_ segments: [ClientSegmentWire.Response]) throws {
        try modelContext.replace(with: segments.enumerated().map { ClientSegment(wire: $1, rank: $0) })
    }
}

//
//  ClientSearchOptions.swift
//  FloorMobile
//

import Foundation

/// What a client search asks for beside its text: a sort, its direction, and
/// the tenant's filters picked — `nil` and an empty list leave each to the
/// server's default (the sort `GET setup` marks `isDefault`, every client).
///
/// "My Clients" keeps it whole, and its controls change it through one
/// binding. Hashable so `PagedSearchList` starts the search over, without its
/// cursor, when any of it changes: a cursor belongs to one search.
nonisolated struct ClientSearchOptions: Hashable, Sendable {
    /// A sort's `value` (`ClientSort.value`), e.g. `"lastPurchase"`.
    var sortBy: String?
    /// `nil`, the sort's own (`ClientSort.direction`).
    var direction: ClientSort.Direction?
    /// The filter values picked.
    var filters: [ClientFilterChoice] = []

    /// Whether nothing is picked: the server's defaults all round.
    var isDefault: Bool {
        sortBy == nil && direction == nil && filters.isEmpty
    }
}

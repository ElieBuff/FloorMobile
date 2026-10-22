//
//  ClientSearchOptions.swift
//  FloorMobile
//

import Foundation

/// What a client search asks for beside its text: a sort, its direction, and
/// the tenant's filters picked — `nil` and an empty list leave each to the
/// server's default (the sort `GET setup` marks `isDefault`, every client).
///
/// Hashable so `PagedSearchList` starts the search over when any of it
/// changes: the server's cursor does not carry them.
nonisolated struct ClientSearchOptions: Hashable, Sendable {
    /// A sort's `value` (`ClientSort.value`), e.g. `"lastPurchase"`.
    var sortBy: String?
    var direction: SortDirection?
    /// The picked values' `ref`s (`ClientFilterValue.ref`).
    var filterRefs: [String] = []

    enum SortDirection: String, Sendable {
        case asc
        case desc
    }

    /// Whether nothing is picked: the server's defaults all round.
    var isDefault: Bool {
        sortBy == nil && direction == nil && filterRefs.isEmpty
    }
}

//
//  ClientSearchOptions.swift
//  FloorMobile
//

import Foundation

/// What a client search asks for beside its text: a sort, its direction, and
/// the filters applied, the tenant's values picked and a sentence's pills
/// alike — `nil` and an empty list leave each to the server's default (the
/// sort `GET setup` marks `isDefault`, every client).
///
/// The Clients tab keeps it whole (`ClientsView`), and "Sort & filter"
/// (`ClientSortFilterSheet`) changes it through one binding. Hashable so
/// `PagedSearchList` starts the search over, without its cursor, when any of
/// it changes: a cursor belongs to one search. The sheet composes it in a
/// draft (`ClientFilterDraft`), and "Show" writes it back.
nonisolated struct ClientSearchOptions: Hashable, Sendable {
    /// A sort's `value` (`ClientSort.value`), e.g. `"lastPurchase"`.
    var sortBy: String?
    /// `nil`, the sort's own (`ClientSort.direction`).
    var direction: ClientSort.Direction?
    /// The filters applied, one list as `client/search` takes it: the
    /// tenant's values picked (`.value`) and a sentence's pills (`.filter`).
    var filters: [ClientFilterChoice] = []

    // MARK: - Sort

    /// Picks `sort`, in the direction the server gives it; the filters stay.
    /// Any sort is sent as picked, the default one included: which sort is the
    /// default is the server's to change.
    mutating func pick(_ sort: ClientSort) {
        sortBy = sort.value
        direction = sort.direction
    }

    /// Whether `sort` is the one the search runs: the picked one, in its own
    /// direction — or the server's default while none is picked.
    func isPicked(_ sort: ClientSort) -> Bool {
        guard let sortBy else { return sort.isDefault }
        return sort.value == sortBy && sort.direction == direction
    }
}

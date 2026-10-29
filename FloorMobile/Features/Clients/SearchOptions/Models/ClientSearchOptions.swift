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
/// "My Clients" keeps it whole, and its controls change it through one
/// binding. Hashable so `PagedSearchList` starts the search over, without its
/// cursor, when any of it changes: a cursor belongs to one search. The filters
/// sheet edits a copy of it, a draft, and "Apply" writes its filters back.
nonisolated struct ClientSearchOptions: Hashable, Sendable {
    /// A sort's `value` (`ClientSort.value`), e.g. `"lastPurchase"`.
    var sortBy: String?
    /// `nil`, the sort's own (`ClientSort.direction`).
    var direction: ClientSort.Direction?
    /// The filters applied, one list as `client/search` takes it: the
    /// tenant's values picked (`.value`) and a sentence's pills (`.filter`).
    var filters: [ClientFilterChoice] = []

    /// Whether nothing is picked: the server's defaults all round.
    var isDefault: Bool {
        sortBy == nil && direction == nil && filters.isEmpty
    }

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

    // MARK: - Filters

    /// Whether `value` is among the filter values picked.
    func isPicked(_ value: ClientFilterValue) -> Bool {
        filters.contains { $0.ref == value.ref }
    }

    /// The day picked for `value` — "Since a date" —, or `nil` while it is
    /// not picked or asks for no day.
    func day(pickedFor value: ClientFilterValue) -> Date? {
        guard let parameter = value.dateParameter,
              case .value(_, let parameters)? = filters.first(where: { $0.ref == value.ref }),
              let text = parameters[parameter.name]
        else { return nil }
        return Date(calendarDay: text)
    }

    /// Picks `value` of `filter`, with what the associate filled in for its
    /// parameters (`[name: text]`: the day of "Since a date"). A filter that
    /// takes one value (`single`) lets go of the one it had — the design's
    /// rule: picking "Since a date" deselects "Last 3 months". A value already
    /// picked takes the new parameters, never a second entry.
    mutating func pick(_ value: ClientFilterValue, of filter: ClientFilter, parameters: [String: String] = [:]) {
        if filter.selection == .single {
            let siblings = Set(filter.values.map(\.ref))
            filters.removeAll { $0.ref.map(siblings.contains) == true }
        } else {
            filters.removeAll { $0.ref == value.ref }
        }
        filters.append(.value(ref: value.ref, parameters: parameters))
    }

    /// Lets go of `value`.
    mutating func unpick(_ value: ClientFilterValue) {
        filters.removeAll { $0.ref == value.ref }
    }

    // MARK: - Filter items

    /// The pills of the sentence applied, in their order: the filters it
    /// described (`client/text-filters`), beside the values picked.
    var filterItems: [ClientFilterItem] {
        filters.compactMap(\.item)
    }

    /// Puts `items` in place of the sentence's pills, the values picked left
    /// as they are: a sentence read again replaces what it gave before.
    mutating func replaceFilterItems(with items: [ClientFilterItem]) {
        filters.removeAll { $0.item != nil }
        filters.append(contentsOf: items.map(ClientFilterChoice.filter))
    }

    /// Lets go of the pill `item`, by its `id`: two pills may read alike.
    mutating func remove(_ item: ClientFilterItem) {
        filters.removeAll { $0.item?.id == item.id }
    }
}

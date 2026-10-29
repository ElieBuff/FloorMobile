//
//  ClientFilterItemsWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of `ClientFilterItems`: the filters a sentence comes back as
/// from `client/text-filters`. Read-only: the sentence goes as a one-field
/// dictionary (`Endpoint.clientTextFilters`), with nothing to map.
nonisolated enum ClientFilterItemsWire {
    /// `{ "filters", "notUnderstood" }`, both always there.
    struct Response: Decodable, Sendable {
        var filters: [Item]
        var notUnderstood: [String]
    }

    /// `{ "label", "filter" }`: the filter's words, and its condition in the
    /// filter language (FloorPlatform's `condition.schema.ts`), kept whole.
    struct Item: Decodable, Sendable {
        var label: String
        var filter: JSONValue
    }
}

nonisolated extension ClientFilterItems {
    /// Each filter keeps its words and its condition together, as an item:
    /// the server's `filter` becomes the item's `condition`.
    init(wire: ClientFilterItemsWire.Response) {
        self.init(
            items: wire.filters.map { ClientFilterItem(label: $0.label, condition: $0.filter) },
            notUnderstood: wire.notUnderstood
        )
    }
}

//
//  ClientFilterChoice.swift
//  FloorMobile
//

import Foundation

/// What the associate applied to the search (`client/search`'s `filters`,
/// `ClientFilterChoiceWire`): one of the tenant's filter values, or a filter a
/// sentence described (`client/text-filters`), sent back whole.
nonisolated enum ClientFilterChoice: Hashable, Sendable {
    /// One of the tenant's filter values (`ClientFilterValue`), by its `ref`,
    /// and what the associate filled in for the parameters it asks for, each
    /// by its name (`ClientFilterValue.Parameter.name`), e.g. `["since": …]`,
    /// as a string; empty for a value that asks for none.
    case value(ref: String, parameters: [String: String] = [:])
    /// A filter a sentence described, as a pill: its label, to show it again
    /// when the sheet reopens, and its condition, sent back whole.
    case filter(ClientFilterItem)

    /// The value's `ref`; `nil` for a sentence's filter, which has none, so a
    /// lookup by a value's `ref` never finds a pill.
    var ref: String? {
        switch self {
        case .value(let ref, _): ref
        case .filter: nil
        }
    }

    /// The sentence's filter; `nil` for a value of the tenant's filters.
    var item: ClientFilterItem? {
        switch self {
        case .value: nil
        case .filter(let item): item
        }
    }
}

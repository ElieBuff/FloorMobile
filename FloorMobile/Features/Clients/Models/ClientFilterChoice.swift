//
//  ClientFilterChoice.swift
//  FloorMobile
//

import Foundation

/// One of the tenant's filter values the associate picked, as the search
/// sends it back (`client/search`'s `filters`, `ClientFilterChoiceWire`):
/// the value, and what the associate filled in for the parameters it asks
/// for.
///
/// The server takes one more shape of choice — a filter a sentence described
/// (`client/text-filters`), sent back whole — which will join this one, as a
/// case of its own, once the app sends sentences.
nonisolated struct ClientFilterChoice: Hashable, Sendable {
    /// The picked value's `ref` (`ClientFilterValue.ref`).
    var ref: String
    /// Each parameter's value by its name (`ClientFilterValue.Parameter.name`),
    /// e.g. `["since": …]`, as a string. Empty for a value that asks for none.
    var parameters: [String: String] = [:]
}

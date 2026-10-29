//
//  ClientFilterItems.swift
//  FloorMobile
//

import Foundation

/// What a sentence the associate typed or dictated becomes on the server
/// (`client/text-filters`, `ClientService.filterItems(from:using:)`): one item
/// per filter it describes, then the parts of it no filter covers. A sentence
/// nothing covers is an answer too: no item, the sentence in `notUnderstood`.
/// An answer to show, not stored — like `ClientItem`.
nonisolated struct ClientFilterItems: Hashable, Sendable {
    /// One per filter the sentence describes, in the server's order.
    var items: [ClientFilterItem]
    /// The parts of the sentence no filter covers, to show as not understood
    /// whenever there are any.
    var notUnderstood: [String]
}

/// One filter a sentence describes, as the screen shows it — a pill —: its
/// words and its condition together, so removing it removes its condition.
/// The sentence's counterpart of a catalog value (`ClientFilterValue`); once
/// applied, it will go to the search as a case of `ClientFilterChoice`.
nonisolated struct ClientFilterItem: Identifiable, Hashable, Sendable {
    /// The app's own, given at decoding: the server gives none, and an item
    /// must be found again to be removed.
    let id = UUID()
    /// Shown as is: already in the associate's language, never a key.
    var label: String
    /// The server's condition, never read here: sent back whole to the search
    /// (`{ "filter": … }`), which checks it again.
    var condition: JSONValue
}

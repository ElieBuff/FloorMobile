//
//  ClientFilter.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// One of the tenant's "My Clients" filters, as the server sets it up — the
/// `clients.filters` block of `GET setup` — kept for the filters screen.
///
/// What a filter offers, not what an associate picked: the server owns the
/// list, its order and each value's meaning; the app only sends a value's
/// `ref` back to `client/search`. Tied to the tenant like everything stored:
/// `LocalStore.erase` wipes it.
///
/// Not `Syncable`, like `EnumValue`: the block lands whole, so
/// `SetupService` saves the complete set at once.
@Model
nonisolated final class ClientFilter {
    @Attribute(.unique) var id: String
    /// The title's translation key, e.g. `"client.filter.created"`.
    var titleKey: String
    /// `"SINGLE"` today: how many of its values can be picked. Kept raw, like
    /// `statusRaw` elsewhere.
    var selectionRaw: String
    /// The position the server listed it at: the order the screen shows.
    var rank: Int
    /// Its values, in the server's order. Embedded rather than a relationship:
    /// a value has no life outside its filter.
    var values: [ClientFilterValue]

    init(id: String, titleKey: String, selectionRaw: String, rank: Int, values: [ClientFilterValue]) {
        self.id = id
        self.titleKey = titleKey
        self.selectionRaw = selectionRaw
        self.rank = rank
        self.values = values
    }
}

/// One value a `ClientFilter` offers, e.g. "last 3 months" — a composite
/// attribute of its filter.
nonisolated struct ClientFilterValue: Codable, Sendable, Equatable {
    /// What `client/search` gets back when this value is picked.
    var ref: String
    /// A translation key, e.g. `"client.filter.value.last3Months"`…
    var labelKey: String?
    /// …or a label shown as is, for a value the server generates from a list
    /// (the Tier's segments).
    var label: String?
    /// What the associate fills in when picking it, e.g. a `since` date.
    var parameters: [Parameter]

    nonisolated struct Parameter: Codable, Sendable, Equatable {
        var name: String
        /// `"date"` today. Kept raw.
        var typeRaw: String
    }
}

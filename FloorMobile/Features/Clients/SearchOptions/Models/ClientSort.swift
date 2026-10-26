//
//  ClientSort.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// One of the tenant's "My Clients" sorts, as the server sets it up — the
/// `clients.sorts` block of `GET setup` — kept for the sort screen.
///
/// What a sort offers, not what an associate picked: the server owns the
/// list, its order and which one applies by default. The sort screen will
/// send a picked sort's `value` to `client/search`; nothing reads this model
/// yet. Tied to the tenant like everything stored: `LocalStore.erase` wipes
/// it.
///
/// Not `Syncable`, like `ClientFilter`: the block lands whole, so
/// `SetupService` saves the complete set at once.
@Model
nonisolated final class ClientSort {
    /// What `client/search` gets as its sort, e.g. `"lastPurchase"` — and the
    /// sort's identity.
    @Attribute(.unique) var value: String
    /// The label's translation key, e.g. `"client.sort.lastPurchase"`.
    var labelKey: String
    /// `"asc"` or `"desc"`: the order the server applies it in. Kept raw, like
    /// `statusRaw` elsewhere.
    var directionRaw: String
    /// Whether the search applies it when none is sent — one sort of the list.
    var isDefault: Bool
    /// The position the server gives it: the order the screen shows.
    var rank: Int

    init(value: String, labelKey: String, directionRaw: String, isDefault: Bool, rank: Int) {
        self.value = value
        self.labelKey = labelKey
        self.directionRaw = directionRaw
        self.isDefault = isDefault
        self.rank = rank
    }
}

nonisolated extension ClientSort: ContentComparable {

    // MARK: - Typed views

    /// Which way a sort runs: `client/search`'s `direction`, and each sort's
    /// starting one in `GET setup`.
    nonisolated enum Direction: String, Sendable {
        case asc
        case desc
    }

    /// Typed view of `directionRaw`, the way the server starts this sort;
    /// `nil` for a value this app does not know.
    var direction: Direction? { Direction(rawValue: directionRaw) }

    // MARK: - Sync

    /// Whether `other` holds the same content, field by field — what decides
    /// that `ModelContext.replace` leaves the stored sorts alone. Every stored
    /// field above is compared here: one added to the class must be added here
    /// too, or a server change to it alone would never be written.
    func hasSameContent(as other: ClientSort) -> Bool {
        value == other.value && labelKey == other.labelKey && directionRaw == other.directionRaw
            && isDefault == other.isDefault && rank == other.rank
    }
}

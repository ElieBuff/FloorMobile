//
//  Reason.swift
//  FloorMobile
//

import Foundation

/// Why an agenda event or task exists — the server's `reason` (open set).
/// Shared by `AgendaEvent` and `AgendaTask`. Unknown values fall back to
/// `.other`, so a new server reason never breaks decoding or display.
nonisolated enum Reason: String, CaseIterable, Sendable {
    case birthday = "BIRTHDAY"
    case backInStock = "BACK_IN_STOCK"
    case collectionLaunch = "COLLECTION_LAUNCH"
    case vipEvent = "VIP_EVENT"
    case followUp = "FOLLOW_UP"
    case wishlistAvailable = "WISHLIST_AVAILABLE"
    case other = "OTHER"

    /// Maps a raw server value, defaulting to `.other` for anything unknown.
    init(raw: String) {
        self = Reason(rawValue: raw) ?? .other
    }
}

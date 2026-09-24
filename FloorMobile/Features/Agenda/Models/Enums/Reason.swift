//
//  Reason.swift
//  FloorMobile
//

import SwiftUI

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

    /// The fallback list for a picker, used only while the stored vocabulary is
    /// empty — the real list comes from `GET enums`, per entity, because the
    /// server is free to offer a task a reason it does not offer an event.
    ///
    /// `.other` is absent for the same reason it is absent from the payload:
    /// it is where unknown values land, not something anyone picks on purpose.
    static var selectable: [Reason] { allCases.filter { $0 != .other } }
}

/// SwiftUI-facing display for each `Reason`: label, icon, and the fill/tint
/// color pair.
extension Reason {
    var displayLabel: String {
        switch self {
        case .birthday: String(localized: "Birthday")
        case .backInStock: String(localized: "Back in stock")
        case .collectionLaunch: String(localized: "Collection launch")
        case .vipEvent: String(localized: "VIP event")
        case .followUp: String(localized: "Follow-up")
        case .wishlistAvailable: String(localized: "Wishlist available")
        case .other: String(localized: "Other")
        }
    }

    /// The sets of the `Reason/Icons`, `Reason/Fill` and `Reason/Tint` asset
    /// groups carry the server's own value as their name, so a reason finds its
    /// three assets without a case-by-case mapping.
    ///
    /// Looked up by name rather than through Xcode's generated symbols — that
    /// is the price of dropping the mapping, since a renamed set still
    /// compiles. `ReasonTests` walks every case, so a missing set fails a test
    /// instead of showing a blank badge.
    var icon: Image { Image("Reason/Icons/\(rawValue)") }

    /// The category's own color, for the icon glyph and the label text.
    var fillColor: Color { Color("Reason/Fill/\(rawValue)") }

    /// The same color at 10% opacity, for the icon's circular backdrop.
    var tintColor: Color { Color("Reason/Tint/\(rawValue)") }
}

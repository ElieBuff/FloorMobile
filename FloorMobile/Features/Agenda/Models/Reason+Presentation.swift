//
//  Reason+Presentation.swift
//  FloorMobile
//

import SwiftUI

/// SwiftUI-facing display for each `Reason`: label, icon, and the fill/tint
/// color pair from the `Reason/Fill` and `Reason/Tint` asset catalog groups.
/// Kept out of `Reason.swift` itself so that type stays a plain, testable
/// Foundation enum with no SwiftUI dependency.
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

    var icon: Image {
        switch self {
        case .birthday: Image(.Reason.Icons.birthday)
        case .backInStock: Image(.Reason.Icons.backInStock)
        case .collectionLaunch: Image(.Reason.Icons.collectionLaunch)
        case .vipEvent: Image(.Reason.Icons.vipEvent)
        case .followUp: Image(.Reason.Icons.followUp)
        case .wishlistAvailable: Image(.Reason.Icons.wishlistAvailable)
        case .other: Image(.Reason.Icons.other)
        }
    }

    /// The category's own color, for the icon glyph and the label text.
    var fillColor: Color {
        switch self {
        case .birthday: Color(.Reason.Fill.birthday)
        case .backInStock: Color(.Reason.Fill.backInStock)
        case .collectionLaunch: Color(.Reason.Fill.collectionLaunch)
        case .vipEvent: Color(.Reason.Fill.vipEvent)
        case .followUp: Color(.Reason.Fill.followUp)
        case .wishlistAvailable: Color(.Reason.Fill.wishlistAvailable)
        case .other: Color(.Reason.Fill.other)
        }
    }

    /// The same color at 10% opacity, for the icon's circular backdrop.
    var tintColor: Color {
        switch self {
        case .birthday: Color(.Reason.Tint.birthday)
        case .backInStock: Color(.Reason.Tint.backInStock)
        case .collectionLaunch: Color(.Reason.Tint.collectionLaunch)
        case .vipEvent: Color(.Reason.Tint.vipEvent)
        case .followUp: Color(.Reason.Tint.followUp)
        case .wishlistAvailable: Color(.Reason.Tint.wishlistAvailable)
        case .other: Color(.Reason.Tint.other)
        }
    }
}

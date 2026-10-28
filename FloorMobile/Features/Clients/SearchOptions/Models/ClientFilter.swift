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
/// list, its order and each value's meaning. "Filter"
/// (`ClientFilterPickerView`) lists them in `rank` order, each with its
/// values; a value picked goes into `ClientSearchOptions`, which sends its
/// `ref` back in `client/search`'s `filters`. Tied to the tenant like
/// everything stored: `LocalStore.erase` wipes it.
///
/// Not `Syncable`, like `EnumValue`: the block lands whole, so
/// `SetupService` saves the complete set at once.
@Model
nonisolated final class ClientFilter {
    @Attribute(.unique) var id: String
    /// The title's translation key, e.g. `"client.filter.created"`.
    var titleKey: String
    /// `"SINGLE"` or `"MULTIPLE"` (the Tier): how many of its values the
    /// associate may pick — the app's rule (`selection`, applied by
    /// `ClientSearchOptions.pick`), never the server's, which ORs a filter's
    /// picked values either way. Kept raw, like `statusRaw` elsewhere.
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

nonisolated extension ClientFilter: ContentComparable {

    // MARK: - Typed views

    /// How many of its values the associate may pick: one (`single`, a new
    /// pick lets go of the last) or any (`multiple`). The app's rule only —
    /// the search ORs a filter's picked values either way.
    nonisolated enum Selection: String, Sendable {
        case single = "SINGLE"
        case multiple = "MULTIPLE"
    }

    /// Typed view of `selectionRaw`; `nil` for a value this app does not
    /// know, which then picks like `multiple`, as the server reads it.
    var selection: Selection? { Selection(rawValue: selectionRaw) }

    // MARK: - Display

    /// The filter's name on screen, heading its values: its `titleKey` looked
    /// up in the string catalog — the key itself while the catalog has no
    /// entry for it. On the model, like `ClientSort.title`, so every screen
    /// that names a filter reads the same.
    var title: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: titleKey)
    }

    // MARK: - Sync

    /// Whether `other` holds the same content, field by field — what decides
    /// that `ModelContext.replace` leaves the stored filters alone. Every stored field
    /// above is compared here: one added to the class must be added here too,
    /// or a server change to it alone would never be written.
    func hasSameContent(as other: ClientFilter) -> Bool {
        id == other.id && rank == other.rank && titleKey == other.titleKey
            && selectionRaw == other.selectionRaw && values == other.values
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

    /// The value's name on screen: its `label` as is — a segment's name is
    /// never looked up in the string catalog, where it could match a key —
    /// else its `labelKey`'s translation, the key itself while the catalog
    /// has no entry for it. The server sends one or the other (`catalogueOf`,
    /// FloorPlatform's filter engine); the `ref` stands in for a value with
    /// neither, so its row is never blank. A `String`, not a
    /// `LocalizedStringResource` like `ClientFilter.title`: a label has
    /// nothing to look up.
    var title: String {
        if let label { return label }
        guard let labelKey else { return ref }
        return String(localized: LocalizedStringResource(stringLiteral: labelKey))
    }

    /// The day this value asks the associate for — "Since a date"'s `since` —
    /// or `nil` for a value picked as is. Only a value whose one parameter is
    /// a date is drawn with a calendar: the one shape the tenants' filters
    /// have today. A value asking for two dates, or a number, would need its
    /// own.
    var dateParameter: Parameter? {
        guard parameters.count == 1, let parameter = parameters.first, parameter.kind == .date else { return nil }
        return parameter
    }

    nonisolated struct Parameter: Codable, Sendable, Equatable {
        var name: String
        /// `"date"` today. Kept raw.
        var typeRaw: String
        /// Typed view of `typeRaw`; `nil` for a kind this app does not draw.
        var kind: Kind? { Kind(rawValue: typeRaw) }

        /// What a parameter takes.
        nonisolated enum Kind: String, Sendable {
            /// A calendar day, sent as `YYYY-MM-DD` (`Date.calendarDay(in:)`).
            case date
        }
    }
}

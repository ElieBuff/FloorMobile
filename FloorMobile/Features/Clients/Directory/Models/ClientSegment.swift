//
//  ClientSegment.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// One of the brand's client segments, as the server sets it up (the
/// `clientConfiguration.segments` block of `GET setup`), kept to draw a
/// client's segment as a tag (`.tagStyle()`), in its colours.
///
/// What the brand configures, not a client's data: the server owns the list,
/// its order and each segment's colours, saved in the console (Config
/// Tolby). A client's `segment` names one by its `code`, written the same
/// way. Two readers: the list's rows, which draw a client's segment as a tag
/// (`ClientsView`, the profile one day), and "Sort & filter", which draws a
/// dot in colours drawn from the tag's (`dotColors`) on the pills of the
/// filter whose values are the segments (`ClientFilter.valueField`,
/// `ClientSortFilterView`'s own `@Query`). In `Directory` all the same: it
/// describes a client's segment, and `SearchOptions` only reads it. Tied to
/// the tenant like everything stored: `LocalStore.erase` wipes it.
///
/// Not `Syncable`, like `ClientSort`: the block lands whole, so
/// `SetupService` saves the complete set at once.
@Model
nonisolated final class ClientSegment {
    /// The segment's name as a client's `segment` writes it, case included,
    /// e.g. `"VIC"`; also the segment's identity.
    @Attribute(.unique) var code: String
    /// The tag's fill, `#RRGGBB` or `#RRGGBBAA` (its opacity last), raw as
    /// the server sends it; `nil` while the console has not saved the
    /// segment's colours.
    var backgroundColorHex: String?
    /// The tag's text colour, in the same form; `nil` likewise.
    var textColorHex: String?
    /// Its place in the brand's order, from 0.
    var rank: Int

    init(code: String, backgroundColorHex: String?, textColorHex: String?, rank: Int) {
        self.code = code
        self.backgroundColorHex = backgroundColorHex
        self.textColorHex = textColorHex
        self.rank = rank
    }
}

nonisolated extension ClientSegment {

    // MARK: - Lookup

    /// The segment among `segments` that `code` names, or `nil` — for no
    /// code, and for one the brand does not list. The same code, case
    /// included, as the server writes it on a client and in a filter's
    /// values. The one place a segment is found by its code: a client's row
    /// and a filter's pill must name the same segment.
    static func named(_ code: String?, in segments: [ClientSegment]) -> ClientSegment? {
        guard let code else { return nil }
        return segments.first { $0.code == code }
    }

    // MARK: - Display

    /// The segment's two colours as the server sends them, read; `nil` when
    /// either one is missing or does not read: the console has not coloured
    /// the segment yet. One pair for light and dark alike.
    private var resolvedColors: (background: Color.Resolved, text: Color.Resolved)? {
        guard let backgroundHex = backgroundColorHex,
              let background = Color.Resolved(hex: backgroundHex),
              let textHex = textColorHex,
              let text = Color.Resolved(hex: textHex)
        else { return nil }
        return (background, text)
    }

    /// The tag's fill and text colours, or `nil` when either one is missing
    /// or does not read. `nil` means no tag at all (decision of 15/11). The
    /// segment's dot in "Sort & filter" takes its own from them (`dotColors`).
    var tagColors: (background: Color, foreground: Color)? {
        resolvedColors.map { (Color($0.background), Color($0.text)) }
    }

    /// The colours of the segment's dot in "Sort & filter"
    /// (`ClientSortFilterView`), drawn from the tag's (decision of 18/11):
    /// its fill is the tag's background 2.5 times as opaque, up to opaque —
    /// the mockup's dots against its tags (25, 55 and 100 % for 10, 24 and
    /// 100 %) —, its ring the tag's text colour at 35 %, a soft edge rather
    /// than a dark circle around a pale centre. `nil` as `tagColors` is: no
    /// dot for a segment without its colours.
    var dotColors: (fill: Color, ring: Color)? {
        guard var (fill, ring) = resolvedColors else { return nil }
        fill.opacity = min(1, fill.opacity * 2.5)
        ring.opacity *= 0.35
        return (Color(fill), Color(ring))
    }
}

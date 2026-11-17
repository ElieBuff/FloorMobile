//
//  ClientSegment.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// One of the brand's client segments, as the server sets it up (the
/// `clientConfiguration.segments` block of `GET setup`), kept to draw a
/// client's segment in a `Tag`, in its colours.
///
/// What the brand configures, not a client's data: the server owns the list,
/// its order and each segment's colours, saved in the console (Config
/// Tolby). A client's `segment` names one by its `code`, written the same
/// way. In `Directory`: it shows a client's segment (the list's rows, the
/// profile one day); it neither sorts nor filters. Tied to the tenant like
/// everything stored: `LocalStore.erase` wipes it.
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

    // MARK: - Display

    /// The tag's fill and text colours, or `nil` when either one is missing
    /// or does not read. `nil` means no tag at all (decision of 15/11): the
    /// console has not coloured the segment yet. One pair for light and dark
    /// alike, as the server serves it.
    var tagColors: (background: Color, foreground: Color)? {
        guard let backgroundHex = backgroundColorHex,
              let background = Color.Resolved(hex: backgroundHex),
              let textHex = textColorHex,
              let foreground = Color.Resolved(hex: textHex)
        else { return nil }
        return (Color(background), Color(foreground))
    }
}

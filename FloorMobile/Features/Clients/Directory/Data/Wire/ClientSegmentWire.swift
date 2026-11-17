//
//  ClientSegmentWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `ClientSegment`: one entry of the
/// `clientConfiguration.segments` block of `GET setup` (`SetupWire`).
/// Read-only: there is no `Request`.
nonisolated enum ClientSegmentWire {
    struct Response: Decodable, Sendable {
        /// As a client's `segment` writes it, case included.
        var code: String
        var style: Style
    }

    /// The tag's colours, each `#RRGGBB` or `#RRGGBBAA` (opacity last). The
    /// server sends `{}`, both colours absent, for a segment the console has
    /// not saved yet. Its migration leaves every brand that way until an admin
    /// saves its segments.
    struct Style: Decodable, Sendable {
        var backgroundColor: String?
        var textColor: String?
    }
}

nonisolated extension ClientSegment {
    /// The rank is the segment's place in the block, since the server lists
    /// the segments in the brand's order.
    convenience init(wire: ClientSegmentWire.Response, rank: Int) {
        self.init(
            code: wire.code,
            backgroundColorHex: wire.style.backgroundColor,
            textColorHex: wire.style.textColor,
            rank: rank
        )
    }
}

//
//  ClientSortWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `ClientSort`: one entry of the `clients.sorts` block of
/// `GET setup` (`SetupWire`). Read-only: there is no `Request`.
nonisolated enum ClientSortWire {
    struct Response: Decodable, Sendable {
        var value: String
        var labelKey: String
        var direction: String
        var isDefault: Bool
        var position: Int
    }
}

nonisolated extension ClientSort {
    /// The server's `position` becomes the rank the screen orders by.
    convenience init(wire: ClientSortWire.Response) {
        self.init(
            value: wire.value,
            labelKey: wire.labelKey,
            directionRaw: wire.direction,
            isDefault: wire.isDefault,
            rank: wire.position
        )
    }
}

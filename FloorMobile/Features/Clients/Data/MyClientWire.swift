//
//  MyClientWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `MyClient`: what `client/search?scope=mine` serves.
/// Read-only.
nonisolated enum MyClientWire {
    /// One of the associate's own clients as `client/search?scope=mine` serves
    /// it — the server's minimal card, plus the client's email and phone. Only
    /// what `MyClient` reads is decoded; the card also carries the segment, the
    /// store and the associate, which the list does not show. The page decodes
    /// as a `CursorPage`.
    struct Response: Decodable, Sendable {
        var id: String
        var firstName: String?
        var lastName: String?
        var primaryEmail: String?
        var primaryPhone: String?
    }
}

nonisolated extension MyClient {
    /// Maps the wire format into what the list shows, the name flattened into
    /// a display name.
    init(wire: MyClientWire.Response) {
        self.init(
            id: wire.id,
            displayName: PersonName.display(first: wire.firstName, last: wire.lastName),
            primaryEmail: wire.primaryEmail,
            primaryPhone: wire.primaryPhone
        )
    }
}

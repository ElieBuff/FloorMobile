//
//  ClientProfileWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `ClientProfile`: what `client/{id}` serves — everything
/// the server holds on one client of the brand: every column, their store and
/// associate, their KPIs, every transaction with its items. Read-only.
nonisolated enum ClientProfileWire {
    /// One client's profile. Only the card is read today, by
    /// `ClientWire.Response` from the same object — the profile's columns
    /// include the card's. Each section the page gains adds its field here
    /// (the transactions, the KPIs…); until then the server's other fields are
    /// ignored.
    struct Response: Decodable, Sendable {
        var client: ClientWire.Response

        init(from decoder: any Decoder) throws {
            client = try ClientWire.Response(from: decoder)
        }
    }
}

nonisolated extension ClientProfile {
    /// Maps the wire format into what the page shows: the card, as every
    /// client list shows it.
    init(wire: ClientProfileWire.Response) {
        self.init(client: ClientItem(wire: wire.client))
    }
}

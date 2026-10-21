//
//  SetupWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of `GET setup`: configuration, never data, one block per
/// subject — all kept by `SetupService`. Read-only: there is no `Request`.
nonisolated enum SetupWire {
    struct Response: Decodable, Sendable {
        /// The values of the app's pickers, entity → field → values, decoded
        /// by `EnumsWire`.
        var enums: EnumsWire.Response
        var clients: Clients
        var salesAssociate: SalesAssociate
    }

    /// The connected associate's block.
    struct SalesAssociate: Decodable, Sendable {
        /// `"Fr"`, `"En"`… — kept raw, the server may add more. `nil` when
        /// the associate has no preference.
        var preferredLanguage: String?
    }

    /// The Clients feature's block.
    struct Clients: Decodable, Sendable {
        /// The tenant's "My Clients" filters, in the order the screen shows
        /// them.
        var filters: [ClientFilterWire.Response]
    }
}

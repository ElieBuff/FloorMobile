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
        /// `nil` only if the associate's record went between the token's
        /// check and this read.
        var salesAssociate: SalesAssociate?
    }

    /// The connected associate's block: the shared projection every response
    /// embeds an associate with — their language included — plus their main
    /// store.
    struct SalesAssociate: Decodable, Sendable {
        /// Who they are, read with the shared fragment off the same object.
        var snapshot: SalesAssociateSnapshotWire
        /// Their main store, in the shape a client's store comes in; `nil`
        /// without one.
        var primaryStore: StoreSnapshotWire?

        private enum CodingKeys: String, CodingKey {
            case primaryStore
        }

        init(from decoder: any Decoder) throws {
            snapshot = try SalesAssociateSnapshotWire(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            primaryStore = try container.decodeIfPresent(StoreSnapshotWire.self, forKey: .primaryStore)
        }
    }

    /// The Clients feature's block.
    struct Clients: Decodable, Sendable {
        /// The tenant's "My Clients" filters, in the order the screen shows
        /// them.
        var filters: [ClientFilterWire.Response]
        /// The tenant's "My Clients" sorts, each with its position.
        var sorts: [ClientSortWire.Response]
    }
}

//
//  BrandClientWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `BrandClient`: what `client/search` serves. Read-only.
nonisolated enum BrandClientWire {
    /// A client of the whole brand as `client/search` serves it — the server's
    /// minimal card. No email, no phone, no spend: left out on purpose, since
    /// the client may belong to any store. The page decodes as a `CursorPage`.
    struct Response: Decodable, Sendable {
        var id: String
        var externalId: String
        var firstName: String?
        var lastName: String?
        var segment: String?
        var storeCode: String?
        var store: StoreWire?
        var salesAssociateExternalId: String?
        var salesAssociate: SalesAssociateWire?

        /// The server spells the associate `SA`; the app spells it out.
        enum CodingKeys: String, CodingKey {
            case id, externalId, firstName, lastName, segment, storeCode, store
            case salesAssociateExternalId = "SAExternalId"
            case salesAssociate = "SA"
        }
    }
}

nonisolated extension BrandClient {
    /// Maps the wire format into what the list shows, flattening the store and
    /// the associate into display names.
    init(wire: BrandClientWire.Response) {
        self.init(
            id: wire.id,
            displayName: PersonName.display(first: wire.firstName, last: wire.lastName),
            segment: wire.segment,
            storeName: wire.store?.name,
            salesAssociateName: wire.salesAssociate.flatMap {
                PersonName.display(first: $0.firstName, last: $0.lastName)
            }
        )
    }
}

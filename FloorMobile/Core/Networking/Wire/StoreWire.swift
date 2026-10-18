//
//  StoreWire.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a store as Floor endpoints embed it — display fields
/// only. A plain struct rather than a `Response`/`Request` pair: no endpoint
/// serves it on its own. Reused by any response that embeds a store in this
/// exact shape; an endpoint serving a richer store object gets its own nested
/// type instead of growing this one.
nonisolated struct StoreWire: Decodable {
    var id: String?
    var name: String?
    var storeCode: String?
}

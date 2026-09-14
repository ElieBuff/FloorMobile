//
//  StoreDTO.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a store as Floor endpoints serve it — display fields
/// only. Reused by any DTO whose payload embeds a store in this exact shape;
/// an endpoint serving a richer store object gets its own nested type instead
/// of growing this one.
nonisolated struct StoreDTO: Decodable {
    var id: String?
    var name: String?
    var storeCode: String?
}

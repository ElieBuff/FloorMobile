//
//  StoreSummary.swift
//  FloorMobile
//

import Foundation

/// A store embedded in a `@Model` for display: a value snapshot stored as a
/// SwiftData composite attribute. Its members can't be used in a `@Query`
/// predicate.
nonisolated struct StoreSummary: Codable, Sendable, Equatable {
    var id: String?
    var name: String?
    var storeCode: String?

    init(id: String? = nil, name: String? = nil, storeCode: String? = nil) {
        self.id = id
        self.name = name
        self.storeCode = storeCode
    }

    init(dto: StoreDTO) {
        self.init(id: dto.id, name: dto.name, storeCode: dto.storeCode)
    }
}

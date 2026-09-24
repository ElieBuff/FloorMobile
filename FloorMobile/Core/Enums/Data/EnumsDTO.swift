//
//  EnumsDTO.swift
//  FloorMobile
//

import Foundation

/// Wire format of `GET enums`: entity → field → allowed values.
///
/// An open dictionary rather than typed structs, on purpose. The payload
/// grows: the day the backend adds `"client": { "segment": [...] }`, typed
/// structs would drop it on the floor until the next app release, while a
/// dictionary carries it into the store for a later release to pick up.
typealias EnumsPayload = [String: [String: [String]]]

/// One row of the flattened payload — derived from `EnumsPayload`, never
/// decoded on its own.
nonisolated struct FieldOptionDTO: Sendable {
    let entityName: String
    let field: String
    let value: String
    let rank: Int

    /// Flattens the nested payload into rows. Entities and fields are sorted
    /// so the result never depends on dictionary ordering; the values inside a
    /// field keep the server's order, which becomes `rank`.
    static func rows(from payload: EnumsPayload) -> [FieldOptionDTO] {
        payload.sorted { $0.key < $1.key }.flatMap { entityName, fields in
            fields.sorted { $0.key < $1.key }.flatMap { field, values in
                values.enumerated().map { index, value in
                    FieldOptionDTO(entityName: entityName, field: field, value: value, rank: index)
                }
            }
        }
    }
}

nonisolated extension FieldOption {
    convenience init(dto: FieldOptionDTO) {
        self.init(entityName: dto.entityName, field: dto.field, value: dto.value, rank: dto.rank)
    }
}

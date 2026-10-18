//
//  EnumsWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of `GET enums`. Read-only: there is no `Request`.
nonisolated enum EnumsWire {
    /// Entity → field → allowed values.
    ///
    /// An open dictionary rather than typed structs, on purpose. The payload
    /// grows: the day the backend adds `"client": { "segment": [...] }`, typed
    /// structs would drop it on the floor until the next app release, while a
    /// dictionary carries it into the store for a later release to pick up.
    typealias Response = [String: [String: [String]]]

    /// One row of the flattened response — derived from `Response`, never
    /// decoded on its own.
    struct Row: Sendable {
        let entityName: String
        let field: String
        let value: String
        let rank: Int
    }

    /// Flattens the nested response into rows. Entities and fields are sorted
    /// so the result never depends on dictionary ordering; the values inside a
    /// field keep the server's order, which becomes `rank`.
    static func rows(from response: Response) -> [Row] {
        response.sorted { $0.key < $1.key }.flatMap { entityName, fields in
            fields.sorted { $0.key < $1.key }.flatMap { field, values in
                values.enumerated().map { index, value in
                    Row(entityName: entityName, field: field, value: value, rank: index)
                }
            }
        }
    }
}

nonisolated extension FieldOption {
    convenience init(wire: EnumsWire.Row) {
        self.init(entityName: wire.entityName, field: wire.field, value: wire.value, rank: wire.rank)
    }
}

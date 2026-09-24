//
//  FieldOption.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// One allowed value for an open-set field of the API's data model — the
/// vocabulary served by `GET enums` (`task.reason`, `event.reason`, …).
///
/// Stored flat, one row per value, rather than as one typed object per entity:
/// the server adds entities and fields over time, and a flat row absorbs them
/// without a schema change. What the app *displays* for a value stays local
/// (see `Reason+Presentation`); what the app *offers* comes from here.
///
/// Not `Syncable`: the mark-and-sweep token exists for data arriving in pages,
/// where deleting first would empty the store if a page failed. This payload
/// lands whole, so `EnumsService` simply replaces the set.
@Model
nonisolated final class FieldOption {
    /// `"task.reason|BIRTHDAY"`. Unique: the sync rewrites everything, but the
    /// invariant costs one attribute and rules out a duplicate should another
    /// code path ever insert the same value twice.
    @Attribute(.unique) var id: String

    /// `"task"`, `"event"`, and whatever the server adds next.
    ///
    /// Named `entityName`, not `entity`: `@Model` is backed by CoreData, and
    /// `NSManagedObject` already owns an `entity` of type `NSEntityDescription`.
    /// A stored property of that name makes SwiftData read the entity
    /// description and cast it to `String` — the process aborts on the first
    /// insert.
    var entityName: String
    var field: String
    /// The raw server value, e.g. `"BIRTHDAY"`. Kept raw, like `statusRaw`
    /// elsewhere: typing it is the presentation layer's business.
    var value: String
    /// The position the server listed it at. A picker shows the vocabulary in
    /// the order the backend chose — a product decision, not an alphabetical
    /// accident.
    var rank: Int

    init(entityName: String, field: String, value: String, rank: Int) {
        self.id = Self.identifier(entityName: entityName, field: field, value: value)
        self.entityName = entityName
        self.field = field
        self.value = value
        self.rank = rank
    }

    static func identifier(entityName: String, field: String, value: String) -> String {
        "\(entityName).\(field)|\(value)"
    }
}

nonisolated extension FieldOption {
    /// Names an (entity, field) pair of the server's vocabulary. Declared
    /// here, but the constants belong to whoever reads them: each feature adds
    /// its own in an extension, so `Core` never learns feature names.
    struct Key: Sendable, Equatable {
        let entityName: String
        let field: String
    }

    /// `key`'s allowed values, in the server's own order — ready for `@Query`.
    /// The two locals are not decoration: `#Predicate` cannot capture a
    /// property of an outer value, only plain variables.
    static func descriptor(for key: Key) -> FetchDescriptor<FieldOption> {
        let entityName = key.entityName
        let field = key.field
        return FetchDescriptor<FieldOption>(
            predicate: #Predicate { $0.entityName == entityName && $0.field == field },
            sortBy: [SortDescriptor(\.rank, order: .forward)]
        )
    }
}

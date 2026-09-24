//
//  EnumsService.swift
//  FloorMobile
//

import Foundation
import SwiftData
import os

/// Keeps the server's field vocabulary in SwiftData. A `@ModelActor`, like the
/// other services, so its writes run off the main actor.
@ModelActor
actor EnumsService {

    /// Replaces the stored vocabulary with what the server currently allows —
    /// but only when the two actually differ.
    ///
    /// The vocabulary is identical from one launch to the next nearly every
    /// time, and this sync is what holds the first frame back: `RootView` keeps
    /// the loading screen up until it returns. Rewriting it unconditionally
    /// meant deleting and re-inserting every row at each launch, and having the
    /// main context merge that whole change set, right as the tab tree was
    /// being built. An unchanged payload now costs one fetch and no write.
    ///
    /// No mark-and-sweep token here, unlike the other services: that machinery
    /// protects data arriving in pages, where deleting first would leave the
    /// store empty if a page failed. This payload is small and lands whole, so
    /// the complete set is in memory before anything is touched — and a failed
    /// request leaves the previous vocabulary untouched.
    ///
    /// Deleted row by row rather than with `delete(model:)`: a batch delete
    /// reaches the store immediately, and a reader landing between it and the
    /// save would see an empty list. Per-object deletes are held until the
    /// save, so readers go straight from the old values to the new ones.
    func synchronize(using client: APIClient) async throws {
        let payload: EnumsPayload = try await client.send(.enums())
        let rows = FieldOptionDTO.rows(from: payload)

        let stored = try modelContext.fetch(
            FetchDescriptor<FieldOption>(sortBy: [SortDescriptor(\.id, order: .forward)])
        )
        // Logged, not silent: "the launch wrote nothing" is the whole point of
        // the comparison above, and it is otherwise invisible from the outside.
        guard Self.differs(stored: stored, from: rows) else {
            AppLog.sync.debug(
                "Vocabulary unchanged (\(rows.count, privacy: .public) values), store left alone"
            )
            return
        }
        AppLog.sync.debug(
            "Vocabulary changed: \(stored.count, privacy: .public) stored → \(rows.count, privacy: .public) served, rewriting"
        )

        for option in stored {
            modelContext.delete(option)
        }
        for row in rows {
            modelContext.insert(FieldOption(dto: row))
        }
        try modelContext.save()
    }

    /// Whether the served vocabulary differs from the stored one.
    ///
    /// Compared on the identity *and* the rank of every row: `rank` carries the
    /// order the server listed a field's values in, which is the order the
    /// pickers show, so a reordering is a real change even when the set of
    /// values is the same.
    ///
    /// Both sides are put in `id` order to compare like with like — `rows` is
    /// flattened in (entity, field) order, which is not the same thing.
    private static func differs(stored: [FieldOption], from rows: [FieldOptionDTO]) -> Bool {
        guard stored.count == rows.count else { return true }
        let incoming = rows
            .map {
                (
                    id: FieldOption.identifier(entityName: $0.entityName, field: $0.field, value: $0.value),
                    rank: $0.rank
                )
            }
            .sorted { $0.id < $1.id }
        return zip(stored, incoming).contains { $0.id != $1.id || $0.rank != $1.rank }
    }
}

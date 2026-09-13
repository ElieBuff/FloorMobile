//
//  ModelReconcile.swift
//  FloorMobile
//

import SwiftData

extension ModelContext {
    /// Reconciles a local model collection to match a server-provided set:
    /// upserts every incoming element and deletes the local rows the server
    /// no longer returns. Caller saves nothing — this performs the `save()`.
    ///
    /// Upsert relies on the model's identity key being `@Attribute(.unique)`,
    /// so re-inserting a known id replaces the stored row in place instead of
    /// duplicating it. Assumes the incoming set is the *full* current set
    /// (no pagination).
    func reconcile<Incoming, Model: PersistentModel, ID: Hashable>(
        incoming: [Incoming],
        incomingID: KeyPath<Incoming, ID>,
        modelID: KeyPath<Model, ID>,
        make: (Incoming) -> Model
    ) throws {
        let incomingIDs = Set(incoming.map { $0[keyPath: incomingID] })

        let existing = try fetch(FetchDescriptor<Model>())
        for row in existing where !incomingIDs.contains(row[keyPath: modelID]) {
            delete(row)
        }

        for element in incoming {
            insert(make(element))
        }

        try save()
    }
}

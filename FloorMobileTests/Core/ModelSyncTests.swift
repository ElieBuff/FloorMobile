//
//  ModelSyncTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("ModelContext sync helpers")
@MainActor
struct ModelSyncTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AIAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func action(_ id: String, title: String, token: String) -> AIAction {
        let action = AIAction(id: id, agentKey: "a", type: "t", title: title, reason: "r",
                              statusRaw: "PENDING", createdAt: Date(timeIntervalSince1970: 0))
        action.syncToken = token
        return action
    }

    @Test("Upsert inserts new rows and replaces a known id in place")
    func upsertUpserts() throws {
        let context = try makeContext()
        try context.upsert([action("a", title: "old", token: "t1")]) { $0 }
        // Re-upsert the same id with new values → replaced in place, not duplicated.
        try context.upsert([action("a", title: "new", token: "t1")]) { $0 }

        let rows = try context.fetch(FetchDescriptor<AIAction>())
        #expect(rows.count == 1)
        #expect(rows.first?.title == "new")
    }

    @Test("Mark-and-sweep deletes every row not stamped with the current token")
    func sweepDropsStale() throws {
        let context = try makeContext()
        try context.upsert([
            action("keep", title: "keep", token: "run-2"),
            action("stale", title: "stale", token: "run-1"),
        ]) { $0 }

        let token = "run-2"
        try context.sweep(AIAction.self, matching: #Predicate { $0.syncToken != token })

        let rows = try context.fetch(FetchDescriptor<AIAction>())
        #expect(Set(rows.map(\.id)) == ["keep"])
    }
}

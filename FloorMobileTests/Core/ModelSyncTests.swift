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

    @Test("refresh pages through the cursor and persists every page")
    func refreshPaginatesAllPages() async throws {
        let context = try makeContext()

        try await context.refresh(
            paginatedBy: { cursor in
                switch cursor {
                case nil: CursorPage(items: ["a", "b"], hasMore: true, nextCursor: "c2")
                case "c2": CursorPage(items: ["c"], hasMore: false, nextCursor: nil)
                default: throw AppError.unexpected(description: "unexpected cursor")
                }
            },
            make: { id in self.action(id, title: id, token: "") }
        )

        let rows = try context.fetch(FetchDescriptor<AIAction>())
        #expect(Set(rows.map(\.id)) == ["a", "b", "c"])
    }

    @Test("A failure mid-pagination aborts before the sweep, preserving data")
    func refreshErrorMidwayKeepsData() async throws {
        let context = try makeContext()
        // A pre-existing row that a sweep would delete.
        try context.upsert([action("existing", title: "keep", token: "old")]) { $0 }

        await #expect(throws: AppError.self) {
            try await context.refresh(
                paginatedBy: { cursor in
                    if cursor == nil { return CursorPage(items: ["a"], hasMore: true, nextCursor: "c2") }
                    throw AppError.network(underlying: nil)
                },
                make: { id in self.action(id, title: id, token: "") }
            )
        }

        // The sweep never ran: page 1's row landed, the old row survived.
        let rows = try context.fetch(FetchDescriptor<AIAction>())
        #expect(Set(rows.map(\.id)) == ["existing", "a"])
    }

    @Test("An empty successful response sweeps the whole store")
    func refreshEmptyResponseWipesAll() async throws {
        let context = try makeContext()
        try context.upsert([action("gone", title: "gone", token: "old")]) { $0 }

        try await context.refresh(
            from: { [String]() },
            make: { id in self.action(id, title: id, token: "") }
        )

        let rows = try context.fetch(FetchDescriptor<AIAction>())
        #expect(rows.isEmpty)
    }
}

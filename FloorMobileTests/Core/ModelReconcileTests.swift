//
//  ModelReconcileTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("ModelContext.reconcile")
@MainActor
struct ModelReconcileTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AIAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func action(_ id: String, title: String) -> AIAction {
        AIAction(id: id, agentKey: "a", type: "t", title: title, reason: "r",
                 statusRaw: "PENDING", createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test("Upserts incoming, prunes absent, updates in place")
    func reconciles() throws {
        let context = try makeContext()
        context.insert(action("keep", title: "old"))
        context.insert(action("stale", title: "gone"))
        try context.save()

        let incoming = [action("keep", title: "new"), action("fresh", title: "fresh")]
        try context.reconcile(
            incoming: incoming,
            incomingID: \.id,
            modelID: \AIAction.id,
            make: { $0 }
        )

        let rows = try context.fetch(FetchDescriptor<AIAction>())
        #expect(Set(rows.map(\.id)) == ["keep", "fresh"])
        #expect(rows.first { $0.id == "keep" }?.title == "new")
    }

    @Test("Empty incoming clears the store")
    func emptyIncomingPrunesAll() throws {
        let context = try makeContext()
        context.insert(action("a", title: "x"))
        try context.save()

        try context.reconcile(
            incoming: [AIAction](),
            incomingID: \.id,
            modelID: \AIAction.id,
            make: { $0 }
        )

        #expect(try context.fetch(FetchDescriptor<AIAction>()).isEmpty)
    }
}

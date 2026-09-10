//
//  SessionSyncTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Session sync policy")
@MainActor
struct SessionSyncTests {

    private func seededContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AIAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(AIAction(
            id: "x", agentKey: "a", type: "t", title: "t",
            reason: "r", statusRaw: "PENDING", createdAt: Date(timeIntervalSince1970: 0)
        ))
        try context.save()
        return context
    }

    @Test("An expired session purges local data and signs out")
    func expiredSessionPurgesAndSignsOut() async throws {
        let context = try seededContext()
        let session = AppSession(auth: .preview, api: .preview)

        await SessionSync.run(label: "test", session: session, context: context) {
            throw AppError.authentication(.sessionExpired)
        }

        #expect(try context.fetch(FetchDescriptor<AIAction>()).isEmpty)
        #expect(session.state == .unauthenticated)
    }

    @Test("A network error leaves data and session intact")
    func networkErrorKeepsEverything() async throws {
        let context = try seededContext()
        let session = AppSession(auth: .preview, api: .preview)

        await SessionSync.run(label: "test", session: session, context: context) {
            throw AppError.network(underlying: nil)
        }

        #expect(try context.fetch(FetchDescriptor<AIAction>()).count == 1)
    }
}

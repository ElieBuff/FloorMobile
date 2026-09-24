//
//  TaskActionsTests.swift
//  FloorMobileTests
//

import Foundation
import Synchronization
import SwiftData
import Testing
@testable import FloorMobile

/// The choreography around a status write: paint the tap, wait a beat, send,
/// and put it back if the answer is no. The network and the store belong to
/// `AgendaService`; what is under test here is the timing and the rollback.
@Suite("Task actions")
@MainActor
struct TaskActionsTests {

    /// Short enough that crossing the window costs milliseconds, long enough
    /// that a test meaning to tap *inside* it reliably can.
    private static let grace = Duration.milliseconds(120)

    // MARK: - Painting

    @Test("A control paints the row until a tap is in flight")
    func shownStatusFallsBackOnTheRow() {
        let actions = TaskActions(grace: Self.grace)

        #expect(actions.shownStatus(over: .toDo) == .toDo)
        #expect(actions.shownStatus(over: .completed) == .completed)
    }

    @Test("Settling says whether anything was actually dropped")
    func settleReportsWhatItDropped() {
        let actions = TaskActions(grace: Self.grace)

        // Nothing pending, so nothing for a caller to animate.
        #expect(actions.settle() == false)
    }

    // MARK: - What never leaves the device

    @Test("A tap back onto the status the row already holds sends nothing")
    func tapBackOntoTheStoredStatusIsANoOp() async throws {
        let world = try World()
        let actions = TaskActions(grace: Self.grace)

        actions.move("t1", to: .toDo, stored: .toDo, session: world.session, services: world.services)

        #expect(actions.pendingStatus == nil)
        try await Task.sleep(for: Self.grace * 8)
        #expect(world.requestCount == 0)
        #expect(actions.isWorking == false)
    }

    @Test("A second tap inside the grace period replaces the first, and only one is sent")
    func secondTapReplacesTheFirst() async throws {
        let world = try World()
        let actions = TaskActions(grace: Self.grace)

        actions.move("t1", to: .completed, stored: .toDo, session: world.session, services: world.services)
        actions.move("t1", to: .canceled, stored: .toDo, session: world.session, services: world.services)
        #expect(actions.pendingStatus == .canceled)

        // One request, carrying the status the finger landed on.
        #expect(try await settles { world.requestCount == 1 })
        #expect(world.lastBodyStatus == "CANCELED")
    }

    @Test("A tap taken back inside the grace period never reaches the server")
    func tapTakenBackSendsNothing() async throws {
        let world = try World()
        let actions = TaskActions(grace: Self.grace)

        actions.move("t1", to: .completed, stored: .toDo, session: world.session, services: world.services)
        // Back to where the row already was: the scheduled send is cancelled.
        actions.move("t1", to: .toDo, stored: .toDo, session: world.session, services: world.services)

        try await Task.sleep(for: Self.grace * 8)

        #expect(world.requestCount == 0)
        #expect(actions.pendingStatus == nil)
    }

    // MARK: - When the answer is no

    @Test("A failed write puts the control back and raises an alert")
    func failedWriteRollsBackAndAlerts() async throws {
        let world = try World(statusCode: 500)
        let actions = TaskActions(grace: Self.grace)

        actions.move("t1", to: .completed, stored: .toDo, session: world.session, services: world.services)
        #expect(actions.pendingStatus == .completed)

        // The row never moved, so dropping the optimistic value is the whole
        // rollback — and the advisor is told rather than left guessing.
        #expect(try await settles { actions.alert != nil })
        #expect(actions.pendingStatus == nil)
        #expect(actions.isWorking == false)
    }

    // MARK: - Helpers

    /// Polls until `condition` holds, so a case that crosses the network is not
    /// a guess about how long a round trip takes. This suite passed on its own
    /// and failed inside the full run for exactly that reason.
    ///
    /// Only for asserting that something *happens*: an absence cannot be polled
    /// for, and the two cases that check nothing was sent wait a fixed beat.
    private func settles(
        within timeout: Duration = .seconds(5),
        until condition: () -> Bool
    ) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// What the stub saw. Its own type because `Mutex` is non-Copyable: it
    /// cannot be lifted out of a property to be captured, but a reference to
    /// the object holding it can.
    private final class Recorder: Sendable {
        private let calls = Mutex(0)
        private let body = Mutex<String?>(nil)

        var count: Int { calls.withLock { $0 } }
        var lastStatus: String? { body.withLock { $0 } }

        func record(_ request: URLRequest) {
            calls.withLock { $0 += 1 }
            guard
                let data = request.bodyData,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            body.withLock { $0 = json["status"] as? String }
        }
    }

    /// A session and services over an in-memory store and a stubbed network.
    @MainActor
    private struct World {
        let session: AppSession
        let services: AppServices
        let recorder = Recorder()

        var requestCount: Int { recorder.count }
        var lastBodyStatus: String? { recorder.lastStatus }

        init(statusCode: Int = 200) throws {
            let container = try ModelContainer(
                for: AgendaTask.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let recorder = self.recorder
            let client = APIClient(
                baseURL: URL(string: "https://api.example.com")!,
                tokens: TokenProviding(validToken: { "t" }, refreshedToken: { "t" }),
                session: MockURLProtocol.session { request in
                    recorder.record(request)
                    let response = HTTPURLResponse(
                        url: request.url ?? URL(string: "https://invalid")!,
                        statusCode: statusCode, httpVersion: nil, headerFields: nil
                    )!
                    return (response, Self.savedTask)
                }
            )
            session = AppSession(auth: .preview, api: client)
            services = AppServices(container: container)
        }

        /// What the route answers with: the whole task, as the read payload
        /// shapes it.
        private nonisolated static let savedTask = Data(#"""
            {"id":"t1","status":"COMPLETED","reason":"FOLLOW_UP","title":"x",
             "startDate":"2026-09-24T09:00:00.000Z",
             "createdAt":"2026-09-24T09:00:00.000Z",
             "updatedAt":"2026-09-24T09:00:00.000Z"}
            """#.utf8)
    }
}

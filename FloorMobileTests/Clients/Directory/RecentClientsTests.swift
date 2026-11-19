//
//  RecentClientsTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import FloorMobile

/// The recent clients the list keeps in memory: what `refresh` takes from
/// the server, what a failure leaves, and one request at a time. The network
/// belongs to `ClientService`.
@Suite("Recent clients")
@MainActor
struct RecentClientsTests {

    @Test("Nothing is held before the first answer")
    func emptyAtFirst() {
        #expect(RecentClients().clients == nil)
    }

    @Test("A refresh takes the recent clients the server answers with, in its order")
    func refreshTakesTheAnswer() async throws {
        let world = try World { _ in (200, try Fixture.data("client_recent")) }
        let recents = RecentClients()

        await recents.refresh(session: world.session, services: world.services)

        let expected = try APIClient.makeDecoder()
            .decode(ClientWire.Recents.self, from: try Fixture.data("client_recent"))
            .items.map(\.id)
        #expect(recents.clients?.map(\.id) == expected)
    }

    @Test("A failure is ignored: the clients held stay")
    func failureKeepsTheClientsHeld() async throws {
        let answers = Mutex([200, 500])
        let world = try World { _ in
            let statusCode = answers.withLock { $0.removeFirst() }
            return (statusCode, statusCode == 200 ? try Fixture.data("client_recent") : Data())
        }
        let recents = RecentClients()
        await recents.refresh(session: world.session, services: world.services)
        let held = recents.clients

        await recents.refresh(session: world.session, services: world.services)

        #expect(held?.isEmpty == false)
        #expect(recents.clients == held)
    }

    @Test("A failure before any answer leaves nothing held")
    func failureFirstLeavesNothing() async throws {
        let world = try World { _ in (500, Data()) }
        let recents = RecentClients()

        await recents.refresh(session: world.session, services: world.services)

        #expect(recents.clients == nil)
    }

    @Test("A refresh while one is on its way sends nothing more")
    func oneRequestAtATime() async throws {
        let requests = Mutex(0)
        let world = try World { _ in
            requests.withLock { $0 += 1 }
            return (200, try Fixture.data("client_recent"))
        }
        let recents = RecentClients()

        async let first: Void = recents.refresh(session: world.session, services: world.services)
        async let second: Void = recents.refresh(session: world.session, services: world.services)
        _ = await (first, second)

        #expect(requests.withLock { $0 } == 1)
    }

    // MARK: - Helpers

    /// A session and services over an in-memory store and a stubbed network.
    @MainActor
    private struct World {
        let session: AppSession
        let services: AppServices

        init(answer: @escaping @Sendable (URLRequest) throws -> (Int, Data)) throws {
            // Any model: the clients' service keeps nothing, the others need a store.
            let container = try ModelContainer(
                for: ClientSegment.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let client = APIClient(
                baseURL: URL(string: "https://api.example.com")!,
                tokens: TokenProviding(validToken: { "t" }, refreshedToken: { "t" }),
                session: MockURLProtocol.session { request in
                    let (statusCode, body) = try answer(request)
                    let response = HTTPURLResponse(
                        url: request.url ?? URL(string: "https://invalid")!,
                        statusCode: statusCode, httpVersion: nil, headerFields: nil
                    )!
                    return (response, body)
                }
            )
            // The associate in memory: never the simulator's `UserDefaults`.
            session = AppSession(auth: .preview, api: client, salesAssociateStorage: .inMemory(), storeStorage: .inMemory())
            services = AppServices(container: container)
        }
    }
}

//
//  ClientServiceTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import FloorMobile

@Suite("Client service")
@MainActor
struct ClientServiceTests {

    // MARK: - Sync

    @Test("A first sync pages through everything and keeps the last page's cursor")
    func firstSyncLoadsEverything() async throws {
        let container = try Self.inMemoryContainer()
        let cursor = StoredValue<String>.inMemory()
        let requested = Mutex<[String]>([])
        let api = Self.makeClient { request in
            let url = request.url?.absoluteString ?? ""
            requested.withLock { $0.append(url) }
            let name = url.contains("after=cursor-page-2") ? "client_sync_page2" : "client_sync_page1"
            return (Self.response(request), try Fixture.data(name))
        }

        try await ClientService(modelContainer: container).synchronize(using: api, cursor: cursor)

        let ids = try ModelContext(container).fetch(FetchDescriptor<Client>()).map(\.id)
        #expect(Set(ids) == [
            "0002b7b6-5167-4e0a-88c9-74d7bb83abbd",
            "0009c1e2-77aa-4b1e-9d0f-1b2c3d4e5f60",
            "7f38a537-b8de-48fb-baf1-9dd959b06a49",
        ])
        // No cursor on the first call: the server sends everything.
        #expect(requested.withLock { $0.first?.contains("after=") } == false)
        #expect(cursor.get() == "cursor-pass-1")
    }

    @Test("The next sync sends the kept cursor and updates in place")
    func nextSyncIsADelta() async throws {
        let container = try Self.inMemoryContainer()
        let service = ClientService(modelContainer: container)
        let cursor = StoredValue<String>.inMemory()
        let api = Self.makeClient { request in
            let url = request.url?.absoluteString ?? ""
            let name = switch true {
            case url.contains("after=cursor-pass-1"): "client_sync_delta"
            case url.contains("after=cursor-page-2"): "client_sync_page2"
            default: "client_sync_page1"
            }
            return (Self.response(request), try Fixture.data(name))
        }
        try await service.synchronize(using: api, cursor: cursor)

        try await service.synchronize(using: api, cursor: cursor)

        let clients = try ModelContext(container).fetch(FetchDescriptor<Client>())
        // Updated in place, not duplicated; the others are untouched.
        #expect(clients.count == 3)
        let alice = try #require(clients.first { $0.id == "0002b7b6-5167-4e0a-88c9-74d7bb83abbd" })
        #expect(alice.lastName == "Martinez-Durand")
        #expect(alice.segment == "Loyal")
        #expect(cursor.get() == "cursor-pass-2")
    }

    @Test("A pass cut short keeps the previous cursor")
    func failedPassKeepsTheCursor() async throws {
        let container = try Self.inMemoryContainer()
        let cursor = StoredValue<String>.inMemory("cursor-pass-0")
        // Page 1 comes back; page 2 fails.
        let api = Self.makeClient { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("after=cursor-page-2") {
                return (Self.response(request, statusCode: 500), Data())
            }
            return (Self.response(request), try Fixture.data("client_sync_page1"))
        }

        await #expect(throws: AppError.self) {
            try await ClientService(modelContainer: container).synchronize(using: api, cursor: cursor)
        }

        // What page 1 brought is kept; the cursor is not moved past a pass
        // that did not finish.
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Client>()) == 2)
        #expect(cursor.get() == "cursor-pass-0")
    }

    // MARK: - Prune

    @Test("Clients the store no longer has are deleted, the others kept")
    func pruneDeletesTheDeparted() async throws {
        let container = try Self.inMemoryContainer()
        let context = container.mainContext
        for id in ["0002b7b6-5167-4e0a-88c9-74d7bb83abbd", "7f38a537-b8de-48fb-baf1-9dd959b06a49", "moved-away"] {
            context.insert(Client(id: id, externalId: "ext-\(id)"))
        }
        try context.save()
        let api = Self.makeClient { request in
            (Self.response(request), try Fixture.data("client_filter_ids"))
        }

        try await ClientService(modelContainer: container).pruneDeparted(using: api)

        let ids = try ModelContext(container).fetch(FetchDescriptor<Client>()).map(\.id)
        #expect(Set(ids) == ["0002b7b6-5167-4e0a-88c9-74d7bb83abbd", "7f38a537-b8de-48fb-baf1-9dd959b06a49"])
    }

    // MARK: - My clients search

    @Test("A search of my clients sends scope=mine, the query and cursor, and hands back clients and where to go on")
    func myClientsSearchSendsAndMaps() async throws {
        let container = try Self.inMemoryContainer()
        let requested = Mutex<URLComponents?>(nil)
        let api = Self.makeClient { request in
            requested.withLock { $0 = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) } }
            return (Self.response(request), try Fixture.data("client_my_clients_page"))
        }

        let page = try await ClientService(modelContainer: container)
            .searchMyClients("aliette mar", after: "my-clients-cursor-1", using: api)

        let url = try #require(requested.withLock { $0 })
        #expect(url.path.hasSuffix("client/search"))
        // The server sets whose clients they are: the app only says "mine".
        #expect(url.queryItems?.first { $0.name == "scope" }?.value == "mine")
        #expect(url.queryItems?.first { $0.name == "q" }?.value == "aliette mar")
        #expect(url.queryItems?.first { $0.name == "after" }?.value == "my-clients-cursor-1")
        #expect(page.clients.map(\.displayName) == ["Aliette Martin", nil])
        #expect(page.clients.first?.primaryPhone == "+33612345678")
        #expect(page.nextCursor == "my-clients-cursor-2")
        // Shown, never stored.
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Client>()) == 0)
    }

    @Test("The last page of a search of my clients has nowhere to go on, whatever cursor it carries")
    func lastMyClientsPageHasNoCursor() async throws {
        let api = Self.makeClient { request in
            // hasMore decides: a cursor sent with the last page is not followed.
            let body = Data(#"{"items":[],"hasMore":false,"nextCursor":"my-clients-cursor-9"}"#.utf8)
            return (Self.response(request), body)
        }

        let page = try await ClientService(modelContainer: try Self.inMemoryContainer())
            .searchMyClients("aliette", using: api)

        #expect(page.clients.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("A search of my clients fails fast, being interactive; the brand's still waits")
    func onlyMyClientsSearchIsInteractive() {
        #expect(Endpoint.searchMyClients("aliette").interactive)
        #expect(!Endpoint.searchBrandClients("aliette").interactive)
    }

    @Test(
        "A search of my clients that gets no answer fails as a network error: what makes the list fall back",
        arguments: [URLError.Code.timedOut, .cancelled]
    )
    func unansweredMyClientsSearchFails(code: URLError.Code) async throws {
        // A silent server (timedOut), or no connection (cancelled by the offline canceller).
        let api = Self.makeClient { _ in throw URLError(code) }

        let error = await #expect(throws: AppError.self) {
            try await ClientService(modelContainer: try Self.inMemoryContainer()).searchMyClients("aliette", using: api)
        }

        guard case .network? = error else {
            Issue.record("Expected AppError.network, got \(String(describing: error))")
            return
        }
    }

    @Test("A search of my clients the server refuses fails with its status: an associate attached to no store")
    func refusedMyClientsSearchFails() async throws {
        let api = Self.makeClient { request in
            (Self.response(request, statusCode: 400), Data(#"{"error":"storeCode is required"}"#.utf8))
        }

        let error = await #expect(throws: AppError.self) {
            try await ClientService(modelContainer: try Self.inMemoryContainer()).searchMyClients("aliette", using: api)
        }

        guard case .server(statusCode: 400)? = error else {
            Issue.record("Expected AppError.server(400), got \(String(describing: error))")
            return
        }
    }

    // MARK: - Brand search

    @Test("A brand search sends the query and cursor, and hands back clients and where to go on")
    func brandSearchSendsAndMaps() async throws {
        let container = try Self.inMemoryContainer()
        let requested = Mutex<URLComponents?>(nil)
        let api = Self.makeClient { request in
            requested.withLock { $0 = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) } }
            return (Self.response(request), try Fixture.data("client_search_page"))
        }

        let page = try await ClientService(modelContainer: container)
            .searchBrand("nina lar", after: "search-cursor-1", using: api)

        let url = try #require(requested.withLock { $0 })
        #expect(url.path.hasSuffix("client/search"))
        #expect(url.queryItems?.first { $0.name == "q" }?.value == "nina lar")
        #expect(url.queryItems?.first { $0.name == "after" }?.value == "search-cursor-1")
        #expect(page.clients.map(\.displayName) == ["Nina Larsen", nil])
        #expect(page.nextCursor == "search-cursor-2")
        // Shown, never stored.
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Client>()) == 0)
    }

    @Test("The last page of a brand search has nowhere to go on")
    func lastBrandPageHasNoCursor() async throws {
        let api = Self.makeClient { request in
            let body = Data(#"{"items":[],"hasMore":false,"nextCursor":null}"#.utf8)
            return (Self.response(request), body)
        }

        let page = try await ClientService(modelContainer: try Self.inMemoryContainer())
            .searchBrand("nina", using: api)

        #expect(page.clients.isEmpty)
        #expect(page.nextCursor == nil)
    }

    // MARK: - Helpers

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Client.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private nonisolated static func makeClient(
        handler: @escaping MockURLProtocol.Handler
    ) -> APIClient {
        APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            tokens: TokenProviding(
                validToken: { "valid-token" },
                refreshedToken: { "refreshed-token" }
            ),
            session: MockURLProtocol.session(handler: handler)
        )
    }

    private nonisolated static func response(_ request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://invalid")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

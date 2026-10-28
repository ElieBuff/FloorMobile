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
            .searchClients("aliette mar", in: .mine, after: "my-clients-cursor-1", using: api)

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
            .searchClients("aliette", in: .mine, using: api)

        #expect(page.clients.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("A search of my clients fails fast, being interactive; the brand's still waits")
    func onlyMyClientsSearchIsInteractive() {
        #expect(Endpoint.searchClients("aliette", in: .mine).interactive)
        #expect(!Endpoint.searchClients("aliette", in: .brand).interactive)
    }

    /// A filter choice as the server reads it, decoded apart from the app's
    /// own types.
    private struct SentFilterChoice: Decodable, Equatable {
        var ref: String
        var params: [String: String]?
    }

    @Test("My clients' sort, direction and filters go with the search, the filters as JSON, params only when filled in")
    func myClientsOptionsAreSent() throws {
        let options = ClientSearchOptions(
            sortBy: "lastPurchase",
            direction: .desc,
            filters: [
                ClientFilterChoice(ref: "a"),
                ClientFilterChoice(ref: "b", parameters: ["since": "2026-07-01"]),
            ]
        )

        let items = Endpoint.searchClients("aliette", in: .mine, options: options).query

        #expect(items.first { $0.name == "orderBy" }?.value == "lastPurchase")
        #expect(items.first { $0.name == "direction" }?.value == "desc")
        let filters = try #require(items.first { $0.name == "filters" }?.value)
        let decoded = try JSONDecoder().decode([SentFilterChoice].self, from: Data(filters.utf8))
        #expect(decoded == [
            SentFilterChoice(ref: "a", params: nil),
            SentFilterChoice(ref: "b", params: ["since": "2026-07-01"]),
        ])
    }

    @Test("A brand search takes the sort but never the filters, which the server refuses there")
    func brandSearchNeverSendsFilters() {
        let options = ClientSearchOptions(sortBy: "name", direction: .asc, filters: [ClientFilterChoice(ref: "a")])

        let names = Endpoint.searchClients("nina", in: .brand, options: options).query.map(\.name)

        #expect(names.contains("orderBy"))
        #expect(names.contains("direction"))
        #expect(!names.contains("filters"))
        #expect(!names.contains("scope"))
    }

    @Test("Without a text the search sends no q; with nothing picked, nothing beside it")
    func noTextNoOptions() {
        let withoutText = Endpoint.searchClients(
            nil, in: .mine, options: ClientSearchOptions(filters: [ClientFilterChoice(ref: "a")])
        )
        #expect(!withoutText.query.map(\.name).contains("q"))

        let plain = Endpoint.searchClients("aliette", in: .mine).query.map(\.name)
        #expect(plain == ["scope", "q"])
    }

    // MARK: - Count

    @Test("A count of my clients sends client/count with scope=mine, the text and the filters, and hands back the total")
    func myClientsCountSendsAndMaps() async throws {
        let requested = Mutex<URLComponents?>(nil)
        let api = Self.makeClient { request in
            requested.withLock { $0 = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) } }
            return (Self.response(request), Data(#"{"total":473245}"#.utf8))
        }
        let filters = [ClientFilterChoice(ref: "a"), ClientFilterChoice(ref: "b", parameters: ["since": "2026-07-01"])]

        let total = try await ClientService(modelContainer: try Self.inMemoryContainer())
            .countClients("aliette", in: .mine, filters: filters, using: api)

        #expect(total == 473245)
        let url = try #require(requested.withLock { $0 })
        #expect(url.path.hasSuffix("client/count"))
        #expect(url.queryItems?.first { $0.name == "scope" }?.value == "mine")
        #expect(url.queryItems?.first { $0.name == "q" }?.value == "aliette")
        let sent = try #require(url.queryItems?.first { $0.name == "filters" }?.value)
        let decoded = try JSONDecoder().decode([SentFilterChoice].self, from: Data(sent.utf8))
        #expect(decoded == [
            SentFilterChoice(ref: "a", params: nil),
            SentFilterChoice(ref: "b", params: ["since": "2026-07-01"]),
        ])
    }

    @Test("A count sends the search's text, scope and filters, never its sort, direction or cursor")
    func countSendsWhatTheSearchSendsButTheSort() {
        let filters = [ClientFilterChoice(ref: "a")]
        let options = ClientSearchOptions(sortBy: "lastPurchase", direction: .desc, filters: filters)

        let count = Endpoint.countClients("aliette", in: .mine, filters: filters).query
        let search = Endpoint.searchClients("aliette", in: .mine, options: options, after: "cursor-1").query

        #expect(count.map(\.name) == ["scope", "q", "filters"])
        #expect(search.filter { count.map(\.name).contains($0.name) } == count)
    }

    @Test("A count of the brand sends neither the scope nor the filters, which the server refuses there")
    func brandCountNeverSendsFilters() {
        let names = Endpoint.countClients("nina", in: .brand, filters: [ClientFilterChoice(ref: "a")]).query.map(\.name)

        #expect(names == ["q"])
    }

    @Test("Without a text the count sends no q: the whole scope, on its filters")
    func countWithoutText() {
        let names = Endpoint.countClients(nil, in: .mine, filters: [ClientFilterChoice(ref: "a")]).query.map(\.name)

        #expect(names == ["scope", "filters"])
    }

    @Test("A count fails fast in both scopes: the associate waits on it, and nothing on the device stands in")
    func countIsInteractive() {
        #expect(Endpoint.countClients("aliette", in: .mine).interactive)
        #expect(Endpoint.countClients("aliette", in: .brand).interactive)
    }

    @Test("A count past the server's time limit fails with its 503: what leaves \"Apply\" without a number")
    func countPastTheLimitFails() async throws {
        let api = Self.makeClient { request in
            (Self.response(request, statusCode: 503), Data(#"{"error":"search_timeout"}"#.utf8))
        }

        let error = await #expect(throws: AppError.self) {
            try await ClientService(modelContainer: try Self.inMemoryContainer())
                .countClients(nil, in: .mine, filters: [ClientFilterChoice(ref: "a")], using: api)
        }

        guard case .server(statusCode: 503)? = error else {
            Issue.record("Expected AppError.server(503), got \(String(describing: error))")
            return
        }
    }

    @Test(
        "A search of my clients that gets no answer fails as a network error: what makes the list fall back",
        arguments: [URLError.Code.timedOut, .cancelled]
    )
    func unansweredMyClientsSearchFails(code: URLError.Code) async throws {
        // A silent server (timedOut), or no connection (cancelled by the offline canceller).
        let api = Self.makeClient { _ in throw URLError(code) }

        let error = await #expect(throws: AppError.self) {
            try await ClientService(modelContainer: try Self.inMemoryContainer())
                .searchClients("aliette", in: .mine, using: api)
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
            try await ClientService(modelContainer: try Self.inMemoryContainer())
                .searchClients("aliette", in: .mine, using: api)
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
            .searchClients("nina lar", in: .brand, after: "search-cursor-1", using: api)

        let url = try #require(requested.withLock { $0 })
        #expect(url.path.hasSuffix("client/search"))
        #expect(url.queryItems?.first { $0.name == "scope" } == nil)
        #expect(url.queryItems?.first { $0.name == "q" }?.value == "nina lar")
        #expect(url.queryItems?.first { $0.name == "after" }?.value == "search-cursor-1")
        #expect(page.clients.map(\.displayName) == ["Nina Larsen", nil])
        // A client of the brand comes with no way to reach them.
        #expect(page.clients.allSatisfy { $0.primaryEmail == nil && $0.primaryPhone == nil })
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
            .searchClients("nina", in: .brand, using: api)

        #expect(page.clients.isEmpty)
        #expect(page.nextCursor == nil)
    }

    // MARK: - Helpers

    private static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Client.self, RecentClient.self,
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

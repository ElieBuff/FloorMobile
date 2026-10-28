//
//  APIClientTests.swift
//  FloorMobileTests
//

import Foundation
import Synchronization
import Testing
@testable import FloorMobile

@Suite("APIClient")
struct APIClientTests {

    private struct Client: Codable, Equatable {
        let id: String
        let name: String
    }

    private struct Stamped: Decodable {
        let createdAt: Date
    }

    // MARK: - Request building

    @Test("The Bearer token is sent on every request")
    func bearerHeaderIsSent() async throws {
        let captured = Mutex<String?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            return (Self.response(request, statusCode: 200), Data())
        }

        try await client.send(Endpoint(path: "clients"))

        #expect(captured.withLock { $0 } == "Bearer valid-token")
    }

    @Test("GET parameters land in the query string, with no body")
    func getEncodesQuery() async throws {
        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 200), Data())
        }

        try await client.send(Endpoint(
            path: "clients",
            query: [URLQueryItem(name: "search", value: "martin")]
        ))

        let request = try #require(captured.withLock { $0 })
        #expect(request.url?.absoluteString == "https://api.example.com/clients?search=martin")
        #expect(request.bodyData == nil)
    }

    @Test("A plus sign in a parameter leaves as %2B: the BFF reads a bare one as a space")
    func plusSignIsPercentEncoded() async throws {
        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 200), Data())
        }

        try await client.send(Endpoint(path: "clients", query: [
            URLQueryItem(name: "q", value: "jean+test@example.com"),
            URLQueryItem(name: "filters", value: #"[{"ref":"f1:VIP+"}]"#),
        ]))

        let url = try #require(captured.withLock { $0 }?.url)
        let query = try #require(url.query(percentEncoded: true))
        #expect(!query.contains("+"))
        #expect(query.hasPrefix("q=jean%2Btest@example.com&"))
        // Decoded, each value is back as sent.
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.value)
            == ["jean+test@example.com", #"[{"ref":"f1:VIP+"}]"#])
    }

    @Test("A POST body is JSON-encoded with the right content type")
    func postEncodesJSONBody() async throws {
        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 200), Data())
        }

        try await client.send(Endpoint(
            path: "clients",
            method: .post,
            body: Client(id: "c-1", name: "Marie")
        ))

        let request = try #require(captured.withLock { $0 })
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.bodyData)
        let sent = try JSONDecoder().decode(Client.self, from: body)
        #expect(sent == Client(id: "c-1", name: "Marie"))
    }

    // MARK: - Response decoding

    @Test("Decodes a response, ISO 8601 dates with or without fractional seconds")
    func decodesDates() async throws {
        let json = #"[{"createdAt":"2026-09-08T10:00:00.123Z"},{"createdAt":"2026-09-08T10:00:00Z"}]"#
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), Data(json.utf8))
        }

        let stamps: [Stamped] = try await client.send(Endpoint(path: "stamps"))

        #expect(stamps.count == 2)
        #expect(abs(stamps[0].createdAt.timeIntervalSince(stamps[1].createdAt) - 0.123) < 0.001)
    }

    @Test("A malformed response maps to AppError.decoding")
    func malformedResponseIsDecodingError() async {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), Data(#"{"unexpected":true}"#.utf8))
        }

        await #expect(throws: AppError.self) {
            let _: Client = try await client.send(Endpoint(path: "clients/1"))
        }
    }

    @Test("A server error maps to AppError.server")
    func serverErrorIsMapped() async {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }

        await #expect(throws: AppError.self) {
            try await client.send(Endpoint(path: "clients/1", method: .delete))
        }
    }

    // MARK: - 401 retry

    @Test("A 401 is retried exactly once, with a refreshed token")
    func retriesOnceOn401() async throws {
        let calls = Mutex<[String?]>([])
        let client = Self.makeClient { request in
            let token = request.value(forHTTPHeaderField: "Authorization")
            let isFirst = calls.withLock { calls in
                calls.append(token)
                return calls.count == 1
            }
            if isFirst {
                return (Self.response(request, statusCode: 401), Data())
            }
            return (Self.response(request, statusCode: 200), Data(#"{"id":"c-1","name":"Marie"}"#.utf8))
        }

        let result: Client = try await client.send(Endpoint(path: "clients/1"))

        #expect(result.name == "Marie")
        #expect(calls.withLock { $0 } == ["Bearer valid-token", "Bearer refreshed-token"])
    }

    @Test("A second consecutive 401 gives up with sessionExpired")
    func secondConsecutive401GivesUp() async {
        let callCount = Mutex(0)
        let client = Self.makeClient { request in
            callCount.withLock { $0 += 1 }
            return (Self.response(request, statusCode: 401), Data())
        }

        await #expect(throws: AppError.self) {
            try await client.send(Endpoint(path: "clients"))
        }
        // Exactly two attempts: the original call and one retry, never a third.
        #expect(callCount.withLock { $0 } == 2)
    }

    // MARK: - Session expiry

    /// The policy no screen has to remember: the gateway every call goes
    /// through is what notices, so a caller that handles nothing still ends up
    /// back at login.
    @Test("A terminal 401 raises the session-expiry signal")
    @MainActor
    func terminal401RaisesExpiry() async {
        let expiry = SessionExpiry()
        let client = Self.makeClient(expiry: expiry) { request in
            (Self.response(request, statusCode: 401), Data())
        }

        await #expect(throws: AppError.self) {
            try await client.send(Endpoint(path: "clients"))
        }

        #expect(expiry.hasExpired)
    }

    @Test("A refresh token the server has killed raises it too")
    @MainActor
    func deadRefreshTokenRaisesExpiry() async {
        let expiry = SessionExpiry()
        let client = APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            // The refresh itself is what fails here, before any request leaves.
            tokens: TokenProviding(
                validToken: { throw AppError.authentication(.sessionExpired) },
                refreshedToken: { throw AppError.authentication(.sessionExpired) }
            ),
            session: MockURLProtocol.session { request in
                (Self.response(request, statusCode: 200), Data())
            },
            expiry: expiry
        )

        await #expect(throws: AppError.self) {
            try await client.send(Endpoint(path: "clients"))
        }

        #expect(expiry.hasExpired)
    }

    @Test("An ordinary failure leaves the session alone")
    @MainActor
    func serverErrorDoesNotRaiseExpiry() async {
        let expiry = SessionExpiry()
        let client = Self.makeClient(expiry: expiry) { request in
            (Self.response(request, statusCode: 500), Data())
        }

        await #expect(throws: AppError.self) {
            try await client.send(Endpoint(path: "clients"))
        }

        #expect(!expiry.hasExpired)
    }

    // MARK: - Interactive calls

    @Test("An interactive call gives up on a silent server after 3 s; an ordinary call keeps the session's timeout")
    func interactiveCallTimesOutFast() async throws {
        let timeouts = Mutex<[TimeInterval?]>([])
        let client = Self.makeClient(session: MockURLProtocol.session(taskHandler: { request, task in
            // The request as APIClient built it, before URLSession adds its headers.
            timeouts.withLock { $0.append(task?.originalRequest?.timeoutInterval) }
            return (Self.response(request, statusCode: 200), Data())
        }))

        try await client.send(Endpoint(path: "client/search", interactive: true))
        try await client.send(Endpoint(path: "client/search"))

        // An ordinary request is left as built (URLRequest's default): the session's own timeout applies.
        let untouched = URLRequest(url: URL(string: "https://api.example.com")!).timeoutInterval
        #expect(timeouts.withLock { $0 } == [3, untouched])
    }

    @Test("The offline canceller cancels a task waiting for a connection")
    func offlineCancellerCancelsTheTask() {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        // Created, never resumed: nothing leaves; the canceller is called as URLSession would.
        let task = session.dataTask(with: URL(string: "https://api.example.com/client/search")!)

        APIClient.OfflineCanceller().urlSession(session, taskIsWaitingForConnectivity: task)

        let state = task.state
        #expect(state == .canceling || state == .completed)
    }

    @Test("An interactive call hands URLSession the offline canceller, an ordinary call nothing, and both decode alike")
    func interactiveCallHandsTheCanceller() async throws {
        let handed = Mutex<[String]>([])
        let client = Self.makeClient(session: MockURLProtocol.session(taskHandler: { request, task in
            let delegate = task?.delegate.map { String(describing: type(of: $0)) } ?? "none"
            handed.withLock { $0.append(delegate) }
            return (Self.response(request, statusCode: 200), Data(#"{"id":"c-1","name":"Marie"}"#.utf8))
        }))

        let interactive: Client = try await client.send(Endpoint(path: "client/search", interactive: true))
        let ordinary: Client = try await client.send(Endpoint(path: "clients/1"))

        #expect(handed.withLock { $0 } == ["OfflineCanceller", "none"])
        #expect(interactive == ordinary)
    }

    // MARK: - Helpers

    private nonisolated static func makeClient(
        expiry: SessionExpiry? = nil,
        handler: @escaping MockURLProtocol.Handler
    ) -> APIClient {
        makeClient(expiry: expiry, session: MockURLProtocol.session(handler: handler))
    }

    private nonisolated static func makeClient(expiry: SessionExpiry? = nil, session: URLSession) -> APIClient {
        APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            tokens: TokenProviding(
                validToken: { "valid-token" },
                refreshedToken: { "refreshed-token" }
            ),
            session: session,
            expiry: expiry
        )
    }

    private nonisolated static func response(_ request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://invalid")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

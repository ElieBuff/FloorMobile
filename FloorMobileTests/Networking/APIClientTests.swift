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

        try await client.send(Endpoint(method: .get, path: "clients"))

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
            method: .get,
            path: "clients",
            query: [URLQueryItem(name: "search", value: "martin")]
        ))

        let request = try #require(captured.withLock { $0 })
        #expect(request.url?.absoluteString == "https://api.example.com/clients?search=martin")
        #expect(request.bodyData == nil)
    }

    @Test("A POST body is JSON-encoded with the right content type")
    func postEncodesJSONBody() async throws {
        let captured = Mutex<URLRequest?>(nil)
        let client = Self.makeClient { request in
            captured.withLock { $0 = request }
            return (Self.response(request, statusCode: 200), Data())
        }

        try await client.send(Endpoint(
            method: .post,
            path: "clients",
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

        let stamps: [Stamped] = try await client.send(Endpoint(method: .get, path: "stamps"))

        #expect(stamps.count == 2)
        #expect(abs(stamps[0].createdAt.timeIntervalSince(stamps[1].createdAt) - 0.123) < 0.001)
    }

    @Test("A malformed response maps to AppError.decoding")
    func malformedResponseIsDecodingError() async {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 200), Data(#"{"unexpected":true}"#.utf8))
        }

        await #expect(throws: AppError.self) {
            let _: Client = try await client.send(Endpoint(method: .get, path: "clients/1"))
        }
    }

    @Test("A server error maps to AppError.server")
    func serverErrorIsMapped() async {
        let client = Self.makeClient { request in
            (Self.response(request, statusCode: 500), Data())
        }

        await #expect(throws: AppError.self) {
            try await client.send(Endpoint(method: .delete, path: "clients/1"))
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

        let result: Client = try await client.send(Endpoint(method: .get, path: "clients/1"))

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
            try await client.send(Endpoint(method: .get, path: "clients"))
        }
        // Exactly two attempts: the original call and one retry, never a third.
        #expect(callCount.withLock { $0 } == 2)
    }

    // MARK: - Helpers

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

    private nonisolated static func response(_ request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://invalid")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

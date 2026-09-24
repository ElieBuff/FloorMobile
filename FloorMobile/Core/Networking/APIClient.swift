//
//  APIClient.swift
//  FloorMobile
//

import Foundation
import os

/// Single gateway for every Floor API call: Bearer injection, one retry on
/// 401 with a refreshed token, uniform error mapping to `AppError`, one JSON
/// configuration (ISO 8601 dates, fractional seconds tolerated) and
/// privacy-safe logging.
nonisolated struct APIClient: Sendable {
    private let baseURL: URL
    private let tokens: TokenProviding
    private let session: URLSession
    /// Raised when a call fails for good on authentication. Optional so a
    /// preview or a test can leave it out; in the app it is always there.
    private let expiry: SessionExpiry?

    init(
        baseURL: URL,
        tokens: TokenProviding,
        session: URLSession = APIClient.defaultSession(),
        expiry: SessionExpiry? = nil
    ) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
        self.expiry = expiry
    }

    /// Inert client for SwiftUI previews — never makes real network calls.
    static let preview = APIClient(
        baseURL: URL(string: "https://preview.example.com")!,
        tokens: TokenProviding(validToken: { "" }, refreshedToken: { "" })
    )

    /// The production session: reasonable timeout, waits for connectivity
    /// instead of failing immediately on a flaky store network.
    static func defaultSession(timeout: TimeInterval = 30) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Executes the call and decodes the JSON response.
    func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        let data = try await perform(endpoint)
        do {
            return try Self.makeDecoder().decode(Response.self, from: data)
        } catch let error as DecodingError {
            AppLog.network.error(
                "Decoding \(Response.self, privacy: .public) failed: \(Self.describe(error), privacy: .public)"
            )
            // Full, explicit decoding error (kind, coding path, debug description,
            // underlying error) for diagnosing an API/DTO mismatch.
            AppLog.network.debug(
                "Decoding \(Response.self, privacy: .public) error detail: \(String(reflecting: error), privacy: .public)"
            )
            throw AppError.decoding(underlying: error)
        } catch {
            throw AppError.decoding(underlying: error)
        }
    }

    /// Executes the call, ignoring the response body (e.g. 204s).
    func send(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    /// Raw escape hatch for non-JSON payloads (files, images).
    func data(_ endpoint: Endpoint) async throws -> Data {
        try await perform(endpoint)
    }

    // MARK: - Core

    /// Every call passes through here, which is why the end of the session is
    /// noticed here and nowhere else. A screen that forgets to handle it still
    /// gets the right behaviour; there is nothing to forget.
    private func perform(_ endpoint: Endpoint) async throws -> Data {
        do {
            return try await performRequest(endpoint)
        } catch let error as AppError {
            if case .authentication = error {
                await MainActor.run { expiry?.hasExpired = true }
            }
            throw error
        }
    }

    private func performRequest(_ endpoint: Endpoint) async throws -> Data {
        var request = try makeRequest(endpoint)
        request.setValue("Bearer \(try await tokens.validToken())", forHTTPHeaderField: "Authorization")
        logRequest(request, endpoint)

        var (data, response) = try await execute(request)

        if statusCode(of: response) == 401 {
            // One retry with a freshly refreshed token; a second 401 means
            // the session is really over.
            request.setValue("Bearer \(try await tokens.refreshedToken())", forHTTPHeaderField: "Authorization")
            (data, response) = try await execute(request)
            if statusCode(of: response) == 401 {
                throw AppError.authentication(.sessionExpired)
            }
        }

        guard let status = statusCode(of: response) else {
            throw AppError.network(underlying: nil)
        }
        guard (200..<300).contains(status) else {
            AppLog.network.error(
                "HTTP \(status, privacy: .public) on \(endpoint.path, privacy: .private)"
            )
            // A refusal nearly always explains itself in its body — and the
            // body was being dropped along with it, which left a validation
            // error as an unreadable "400".
            AppLog.network.error(
                "← \(status, privacy: .public) said \(Self.bodyText(data), privacy: .private)"
            )
            throw AppError.server(statusCode: status)
        }
        return data
    }

    private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw AppError.network(underlying: error)
        }
    }

    private func makeRequest(_ endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appending(path: endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.query.isEmpty {
            components?.queryItems = endpoint.query
        }
        guard let url = components?.url else {
            throw AppError.unexpected(description: "Unbuildable URL for endpoint '\(endpoint.path)'")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try Self.makeEncoder().encode(body)
            } catch {
                throw AppError.unexpected(description: "Unencodable body for endpoint '\(endpoint.path)': \(error)")
            }
        }
        return request
    }

    private func statusCode(of response: URLResponse) -> Int? {
        (response as? HTTPURLResponse)?.statusCode
    }

    // MARK: - JSON configuration

    // ISO8601DateFormatter is documented as thread-safe.
    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Internal (not private) so decoding tests and fixtures use the exact
    // same JSON configuration as production calls.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = isoFractional.date(from: string) ?? iso.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized ISO 8601 date '\(string)'"
                )
            }
            return date
        }
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Diagnostics

    /// What the call carries on its way out: the method and path, the query as
    /// it was actually built, and the JSON body as it will actually be sent.
    ///
    /// Read off the `URLRequest` rather than off the `Endpoint`, so the log
    /// shows what goes on the wire instead of a second, possibly different,
    /// encoding of it. The `Authorization` header is deliberately absent — a
    /// token has no business in a log, ever.
    ///
    /// `.private` throughout: a path names a record, a query narrows to one,
    /// and a body carries the advisor's own words. Attached to a debugger the
    /// values show; in the field they are redacted.
    private func logRequest(_ request: URLRequest, _ endpoint: Endpoint) {
        AppLog.network.debug(
            "→ \(endpoint.method.rawValue, privacy: .public) \(endpoint.path, privacy: .private)"
        )
        if let query = request.url?.query, !query.isEmpty {
            AppLog.network.debug("  query \(query, privacy: .private)")
        }
        if let body = request.httpBody {
            AppLog.network.debug("  body \(Self.bodyText(body), privacy: .private)")
        }
    }

    /// A request or response body as text, capped so one large payload cannot
    /// bury the rest of the log. Something that is not UTF-8 — an image, a
    /// file — is reported by its size rather than passed off as text.
    private static func bodyText(_ data: Data, limit: Int = 2_000) -> String {
        guard !data.isEmpty else { return "(empty)" }
        guard let text = String(data: data, encoding: .utf8) else {
            return "(\(data.count) bytes, not text)"
        }
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "… (\(text.count) characters in all)"
    }

    /// One-line, log-friendly summary of a decoding failure.
    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            "missing key '\(key.stringValue)' at \(path(context))"
        case .typeMismatch(let type, let context):
            "type mismatch (expected \(type)) at \(path(context))"
        case .valueNotFound(let type, let context):
            "missing value (expected \(type)) at \(path(context))"
        case .dataCorrupted(let context):
            "corrupted data at \(path(context)): \(context.debugDescription)"
        @unknown default:
            "unknown decoding error"
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        context.codingPath.isEmpty
            ? "root"
            : context.codingPath.map(\.stringValue).joined(separator: ".")
    }
}

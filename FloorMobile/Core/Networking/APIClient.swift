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

    init(
        baseURL: URL,
        tokens: TokenProviding,
        session: URLSession = APIClient.defaultSession()
    ) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
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

    private func perform(_ endpoint: Endpoint) async throws -> Data {
        AppLog.network.debug(
            "→ \(endpoint.method.rawValue, privacy: .public) \(endpoint.path, privacy: .private)"
        )
        var request = try makeRequest(endpoint)
        request.setValue("Bearer \(try await tokens.validToken())", forHTTPHeaderField: "Authorization")

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

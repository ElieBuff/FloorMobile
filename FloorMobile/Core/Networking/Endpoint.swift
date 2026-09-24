//
//  Endpoint.swift
//  FloorMobile
//

import Foundation

/// Describes an API endpoint: path, HTTP method, query parameters, and body.
///
/// Separates the "what to call" from the "how to call it" (authentication,
/// retries, decoding) — all endpoints flow through `APIClient.send(_:)`.
nonisolated struct Endpoint: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    let path: String
    let method: Method
    let query: [URLQueryItem]
    let body: (any Encodable & Sendable)?

    init(
        path: String,
        method: Method = .get,
        query: [URLQueryItem] = [],
        body: (any Encodable & Sendable)? = nil
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
    }
}

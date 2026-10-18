//
//  Endpoint.swift
//  FloorMobile
//

import Foundation

/// Describes an API endpoint: path, HTTP method, query parameters, body, and
/// whether a person is waiting on it.
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
    /// A call a person is waiting on, such as a search while they type: it
    /// fails at once without a connection instead of waiting for one, and
    /// after a few seconds of silence from the server, so the screen can fall
    /// back on what the device holds. Every other call waits, as the session
    /// is set up to.
    let interactive: Bool

    init(
        path: String,
        method: Method = .get,
        query: [URLQueryItem] = [],
        body: (any Encodable & Sendable)? = nil,
        interactive: Bool = false
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.interactive = interactive
    }
}

//
//  Endpoint.swift
//  FloorMobile
//

import Foundation

/// Declarative description of one API call, relative to the client's base URL.
///
/// The encoding rule is implicit: `query` goes to the URL (typically GET),
/// `body` is JSON-encoded (typically POST/PUT/PATCH) — callers never deal
/// with encodings.
nonisolated struct Endpoint: Sendable {
    var method: HTTPMethod
    var path: String
    var query: [URLQueryItem] = []
    var body: (any Encodable & Sendable)?

    init(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable & Sendable)? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }
}

//
//  StubWebAuthenticator.swift
//  FloorMobileTests
//

import Foundation
@testable import FloorMobile

/// Simulates the login window: captures the authorization URL it was given
/// and returns a configurable callback, echoing the `state` by default —
/// exactly what Zitadel would do.
final class StubWebAuthenticator: WebAuthenticating, @unchecked Sendable {
    private let lock = NSLock()
    private var capturedURL: URL?

    /// Overrides the echoed state, to simulate a tampered callback.
    var forcedState: String?
    var code = "test-authorization-code"

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        lock.withLock { capturedURL = url }
        let state = forcedState ?? queryValue("state") ?? ""
        guard let callback = URL(string: "\(callbackScheme)://auth/callback?code=\(code)&state=\(state)") else {
            throw AppError.unexpected(description: "Unbuildable stub callback")
        }
        return callback
    }

    /// The authorization URL the manager built, for assertions.
    var authorizationURL: URL? {
        lock.withLock { capturedURL }
    }

    /// The nonce sent in the authorization request — needed by tests to
    /// forge an ID token that passes the nonce check.
    var sentNonce: String? {
        queryValue("nonce")
    }

    private func queryValue(_ name: String) -> String? {
        guard let url = authorizationURL,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else {
            return nil
        }
        return items.first { $0.name == name }?.value
    }
}

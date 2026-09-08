//
//  TokenProviding.swift
//  FloorMobile
//

import Foundation

/// Seam between `APIClient` and `AuthManager`: a struct of closures (per the
/// project convention) so tests can inject tokens in one line.
nonisolated struct TokenProviding: Sendable {
    /// Returns a currently valid access token (refreshing it if needed).
    var validToken: @Sendable () async throws -> String
    /// Forces a refresh; used after a 401 — the server rejected a token the
    /// client still believed valid.
    var refreshedToken: @Sendable () async throws -> String

    /// Production wiring, forwarding to the actor.
    static func live(_ manager: AuthManager) -> TokenProviding {
        TokenProviding(
            validToken: { try await manager.validToken() },
            refreshedToken: { try await manager.refreshedAccessToken() }
        )
    }
}

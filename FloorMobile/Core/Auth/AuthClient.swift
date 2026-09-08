//
//  AuthClient.swift
//  FloorMobile
//

import Foundation

/// Thin, testable bridge between the UI layer and `AuthManager`: a struct of
/// closures (per the project convention) that tests replace in one line.
nonisolated struct AuthClient: Sendable {
    var restore: @Sendable () async -> IDTokenClaims?
    var signIn: @Sendable () async throws -> IDTokenClaims
    var signOut: @Sendable () async -> Void

    /// Production wiring, forwarding to the actor.
    static func live(_ manager: AuthManager) -> AuthClient {
        AuthClient(
            restore: { await manager.restoreSession() },
            signIn: { try await manager.signIn() },
            signOut: { await manager.signOut() }
        )
    }

    /// Inert client for SwiftUI previews.
    static let preview = AuthClient(
        restore: { nil },
        signIn: { throw AppError.authentication(.userCancelled) },
        signOut: {}
    )
}

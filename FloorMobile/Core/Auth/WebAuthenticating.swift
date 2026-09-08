//
//  WebAuthenticating.swift
//  FloorMobile
//

import Foundation

/// Presents the identity provider's login page and returns the callback URL.
///
/// Abstracted so that `AuthManager` can be unit-tested with a stub: the real
/// implementation (`WebAuthenticator`) wraps `ASWebAuthenticationSession`,
/// which cannot run outside a full app environment.
nonisolated protocol WebAuthenticating: Sendable {
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

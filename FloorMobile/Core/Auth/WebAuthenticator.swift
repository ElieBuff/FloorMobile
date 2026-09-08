//
//  WebAuthenticator.swift
//  FloorMobile
//

import AuthenticationServices
import Foundation
import UIKit

/// Real login window backed by `ASWebAuthenticationSession`.
///
/// The session is ephemeral (no cookies shared with Safari): store devices
/// may be shared between sellers, so a logout must be a real logout and
/// every login asks for credentials again.
@MainActor
final class WebAuthenticator: NSObject, WebAuthenticating {

    /// Kept alive for the duration of the presentation; the session would be
    /// deallocated (and dismissed) if it stayed a local variable.
    private var activeSession: ASWebAuthenticationSession?

    nonisolated func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await present(url: url, callbackScheme: callbackScheme)
    }

    private func present(url: URL, callbackScheme: String) async throws -> URL {
        defer { activeSession = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: AppError.authentication(.userCancelled))
                } else {
                    continuation.resume(throwing: AppError.network(underlying: error))
                }
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            activeSession = session
            session.start()
        }
    }
}

extension WebAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        // No key window can only happen in a degenerate launch state; a login
        // cannot be presented without a connected scene anyway.
        guard let scene = scenes.first else {
            preconditionFailure("No connected window scene to anchor the login sheet")
        }
        return ASPresentationAnchor(windowScene: scene)
    }
}

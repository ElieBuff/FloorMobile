//
//  AppSession.swift
//  FloorMobile
//

import Foundation
import Observation

/// Global session state, injected at the root and observed by RootView.
///
/// Owns the authentication lifecycle from the UI's point of view; the OIDC
/// mechanics live in AuthManager, reached through the injected AuthClient.
@Observable
final class AppSession {
    enum State: Equatable {
        /// Checking the Keychain for a persisted session at launch.
        case loading
        case unauthenticated
        /// The login window is up.
        case authenticating
        case authenticated(User)
        case failed(String)
    }

    private(set) var state: State = .loading
    private let auth: AuthClient

    init(auth: AuthClient) {
        self.auth = auth
    }

    /// Restores a persisted session at launch.
    func start() async {
        if let claims = await auth.restore(), let user = User(claims: claims) {
            state = .authenticated(user)
        } else {
            state = .unauthenticated
        }
    }

    func signIn() async {
        state = .authenticating
        do {
            let claims = try await auth.signIn()
            guard let user = User(claims: claims) else {
                state = .failed(AppError.authentication(.invalidCallback).localizedDescription)
                return
            }
            state = .authenticated(user)
        } catch AppError.authentication(.userCancelled) {
            // Closing the login window is not an error worth showing.
            state = .unauthenticated
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func signOut() async {
        await auth.signOut()
        state = .unauthenticated
    }
}

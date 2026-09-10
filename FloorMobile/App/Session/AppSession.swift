//
//  AppSession.swift
//  FloorMobile
//

import Foundation
import Observation
import SwiftData

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
    
    /// API client used for data synchronization calls.
    private let api: APIClient
    
    /// Timestamp of the last AI actions sync, used to avoid redundant calls.
    private var lastAIActionSync: Date?
    /// Duration for which sync results are cached.
    private let syncCacheDuration: TimeInterval = 60

    init(auth: AuthClient, api: APIClient) {
        self.auth = auth
        self.api = api
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
        lastAIActionSync = nil
    }
    
    /// Synchronizes AI actions from the API to SwiftData.
    ///
    /// Uses a time-based cache to avoid redundant calls when multiple sections
    /// request data simultaneously. Use `force: true` to bypass the cache
    /// (e.g., on pull-to-refresh).
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to insert actions into.
    ///   - force: If `true`, ignores the cache and always fetches fresh data.
    func syncAIActions(context: ModelContext, force: Bool = false) async throws {
        // Check cache unless forced
        if !force,
           let lastSync = lastAIActionSync,
           Date().timeIntervalSince(lastSync) < syncCacheDuration {
            return
        }
        
        guard case .authenticated = state else {
            throw AppError.unexpected(description: "Cannot sync while unauthenticated")
        }

        try await AIActionSync.synchronize(
            using: api,
            context: context
        )
        
        lastAIActionSync = Date()
    }
}

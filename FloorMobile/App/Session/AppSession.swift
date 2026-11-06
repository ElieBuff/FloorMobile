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

    /// The active tenant (Zitadel org) when authenticated, else `nil`.
    /// Drives `LocalStore.enforceTenant`: a change wipes the local store.
    var currentTenantID: String? {
        if case .authenticated(let user) = state { user.tenantID } else { nil }
    }

    /// The configured API client, exposed so features drive their own syncs
    /// (e.g. `AIActionService`) with the session's authenticated client.
    let api: APIClient

    /// The associate signed in, as `GET setup` last described them — their
    /// language included; `nil` before an installation's first setup and
    /// after a sign-out. The same person as the authenticated `User`: to tell
    /// whether a client is theirs, compare the client's associate with
    /// `User.id` — the token's `sub`, their external id — never with this
    /// `id`, the server's internal one.
    ///
    /// A session ended without `signOut()` — a refresh token refused at
    /// launch — leaves the previous associate kept until the next sign-in's
    /// `GET setup` replaces them.
    private(set) var salesAssociate: SalesAssociateSnapshot?
    /// Their main store; `nil` without one.
    private(set) var store: StoreSnapshot?

    /// Where the two above are kept between launches, so a launch offline
    /// still has them. In memory in tests, never the device's defaults.
    private let salesAssociateStorage: StoredValue<SalesAssociateSnapshot>
    private let storeStorage: StoredValue<StoreSnapshot>

    init(
        auth: AuthClient,
        api: APIClient,
        salesAssociateStorage: StoredValue<SalesAssociateSnapshot> = .signedInAssociate,
        storeStorage: StoredValue<StoreSnapshot> = .signedInStore
    ) {
        self.auth = auth
        self.api = api
        self.salesAssociateStorage = salesAssociateStorage
        self.storeStorage = storeStorage
        salesAssociate = salesAssociateStorage.get()
        store = storeStorage.get()
    }

    /// Keeps the associate signed in and their store, as `GET setup` just
    /// described them, for this launch and the next; `nil` clears them.
    func keep(_ salesAssociate: SalesAssociateSnapshot?, store: StoreSnapshot?) {
        self.salesAssociate = salesAssociate
        self.store = store
        salesAssociateStorage.set(salesAssociate)
        storeStorage.set(store)
    }

    /// Restores a persisted session at launch. Only acts from the initial
    /// `loading` state, so a re-fired `.task` can't overwrite a session the
    /// user has since established or torn down.
    func start() async {
        guard case .loading = state else { return }
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

    /// Ends the session — a sign-out, or an expired one (`RootView`) — and
    /// forgets the associate: the next one on this phone never inherits them.
    func signOut() async {
        await auth.signOut()
        keep(nil, store: nil)
        state = .unauthenticated
    }
}

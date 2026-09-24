//
//  SessionExpiry.swift
//  FloorMobile
//

import Observation

/// Raised by `APIClient` the moment the session is over, and acted on once by
/// `RootView`.
///
/// A signal rather than a callback because of the order things are built in:
/// the API client exists before the session that reacts to it, so it cannot
/// capture it. This depends on nothing, so it is created first and handed to
/// both.
///
/// Its whole point is that the policy cannot be forgotten. The consequences of
/// an expired session — purging a tenant's data, returning to login — are not
/// something each screen should remember to ask for; they belong to whoever
/// notices, which is the one gateway every call goes through.
@Observable
final class SessionExpiry {
    /// Set once the API has seen a request fail for good on authentication.
    /// `RootView` clears it after acting, so a later session starts clean.
    var hasExpired = false
}

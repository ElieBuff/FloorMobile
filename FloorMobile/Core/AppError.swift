//
//  AppError.swift
//  FloorMobile
//

import Foundation

/// Single error taxonomy for the whole app.
///
/// Every error surfaced to the user is an `AppError`; lower-level errors are
/// wrapped at the boundary where they occur (network, storage, auth) so that
/// views only ever deal with one type and one user-facing message.
enum AppError: Error {
    case network(underlying: Error?)
    case server(statusCode: Int)
    case decoding(underlying: Error)
    case authentication(AuthFailure)
    case storage(underlying: Error?)
    case unexpected(description: String)

    /// Authentication-specific failure reasons.
    enum AuthFailure: Equatable {
        case userCancelled
        case invalidCallback
        case sessionExpired
        case refreshFailed
    }
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .network:
            String(localized: "Unable to reach the server. Check your connection and try again.")
        case .server(let statusCode):
            String(localized: "The server returned an error (\(statusCode)). Please try again later.")
        case .decoding:
            String(localized: "The server response could not be read. Please try again later.")
        case .authentication(.userCancelled):
            String(localized: "Sign-in was cancelled.")
        case .authentication(.invalidCallback):
            String(localized: "Sign-in failed. Please try again.")
        case .authentication(.sessionExpired):
            String(localized: "Your session has expired. Please sign in again.")
        case .authentication(.refreshFailed):
            String(localized: "Your session could not be renewed. Please sign in again.")
        case .storage:
            String(localized: "Your data could not be saved on this device.")
        case .unexpected:
            String(localized: "Something went wrong. Please try again.")
        }
    }
}

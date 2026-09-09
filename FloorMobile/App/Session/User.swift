//
//  User.swift
//  FloorMobile
//

import Foundation

/// The signed-in user, extracted from the ID token claims.
nonisolated struct User: Equatable, Sendable {
    let id: String
    let name: String
    let email: String?
    let tenantID: String?

    init?(claims: IDTokenClaims) {
        guard let subject = claims.subject, !subject.isEmpty else {
            return nil
        }
        id = subject
        name = claims.name ?? claims.email ?? subject
        email = claims.email
        tenantID = claims.tenantID
    }
}

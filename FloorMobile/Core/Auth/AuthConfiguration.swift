//
//  AuthConfiguration.swift
//  FloorMobile
//

import Foundation

/// OIDC client configuration for the Zitadel instance.
///
/// Production path: values are injected per environment by the active
/// xcconfig (Config/Dev|Staging|Prod.xcconfig) through Info.plist variables,
/// and read back via `fromBundle(_:)`. A missing or empty value throws —
/// it must be visible, never silently defaulted.
nonisolated struct AuthConfiguration: Sendable {
    let issuer: URL
    let clientID: String
    let redirectURI: URL
    let postLogoutRedirectURI: URL
    let scopes: [String]

    init(
        issuer: URL,
        clientID: String,
        redirectURI: URL,
        postLogoutRedirectURI: URL,
        scopes: [String]
    ) {
        self.issuer = issuer
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.postLogoutRedirectURI = postLogoutRedirectURI
        self.scopes = scopes
    }

    /// Builds the configuration from an Info.plist dictionary (testable core).
    init(info: [String: Any]) throws {
        let issuerString = try Self.value("AuthIssuer", in: info)
        guard let issuer = URL(string: issuerString), issuer.scheme == "https" else {
            throw AppError.unexpected(description: "Invalid AuthIssuer '\(issuerString)'")
        }
        let clientID = try Self.value("AuthClientID", in: info)
        let projectID = try Self.value("AuthProjectID", in: info)

        self.init(
            issuer: issuer,
            clientID: clientID,
            redirectURI: URL(string: "floormobile://auth/callback")!,
            postLogoutRedirectURI: URL(string: "floormobile://auth/logout")!,
            scopes: [
                "openid",
                "profile",
                "email",
                "offline_access",
                "urn:zitadel:iam:org:project:id:\(projectID):aud",
            ]
        )
    }

    /// Reads the environment values injected by the active xcconfig.
    static func fromBundle(_ bundle: Bundle = .main) throws -> AuthConfiguration {
        try AuthConfiguration(info: bundle.infoDictionary ?? [:])
    }

    private static func value(_ key: String, in info: [String: Any]) throws -> String {
        guard let value = info[key] as? String, !value.isEmpty else {
            throw AppError.unexpected(description: """
                Missing or empty Info.plist key '\(key)' — is the xcconfig \
                assigned to the current build configuration?
                """)
        }
        return value
    }

    /// Dev values, used by tests and SwiftUI previews.
    static let dev = AuthConfiguration(
        issuer: URL(string: "https://dev-q7qkap.eu1.zitadel.cloud")!,
        clientID: "389695826299033234",
        redirectURI: URL(string: "floormobile://auth/callback")!,
        postLogoutRedirectURI: URL(string: "floormobile://auth/logout")!,
        scopes: [
            "openid",
            "profile",
            "email",
            "offline_access",
            "urn:zitadel:iam:org:project:id:378848396062002729:aud",
        ]
    )
}

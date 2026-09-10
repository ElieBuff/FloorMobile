//
//  APIConfiguration.swift
//  FloorMobile
//

import Foundation

/// Configuration for the Floor API endpoints.
///
/// Production path: the base URL is injected per environment by the active
/// xcconfig (Config/Dev|Staging|Prod.xcconfig) through Info.plist variables,
/// and read back via `fromBundle(_:)`. A missing or empty value throws.
nonisolated struct APIConfiguration: Sendable {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Builds the configuration from an Info.plist dictionary (testable core).
    init(info: [String: Any]) throws {
        let baseURLString = try Self.value("APIBaseURL", in: info)
        guard let baseURL = URL(string: baseURLString) else {
            throw AppError.unexpected(description: "Invalid APIBaseURL '\(baseURLString)'")
        }
        self.baseURL = baseURL
    }

    /// Reads the environment values injected by the active xcconfig.
    static func fromBundle(_ bundle: Bundle = .main) throws -> APIConfiguration {
        try APIConfiguration(info: bundle.infoDictionary ?? [:])
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

}

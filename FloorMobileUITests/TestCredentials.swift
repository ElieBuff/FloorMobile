//
//  TestCredentials.swift
//  FloorMobileUITests
//

import Foundation

/// Test account credentials, loaded from `TestCredentialsSecret.json` — a
/// gitignored file each developer (or the CI) provides locally.
/// See `TestCredentials.example.json` for the expected shape.
struct TestCredentials: Decodable {
    let username: String
    let password: String

    static func load() -> TestCredentials? {
        final class BundleToken {}
        guard let url = Bundle(for: BundleToken.self)
            .url(forResource: "TestCredentialsSecret", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let credentials = try? JSONDecoder().decode(TestCredentials.self, from: data),
            !credentials.password.isEmpty
        else {
            return nil
        }
        return credentials
    }
}

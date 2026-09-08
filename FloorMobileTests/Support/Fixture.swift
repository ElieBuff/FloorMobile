//
//  Fixture.swift
//  FloorMobileTests
//

import Foundation

/// Class used only to locate the test bundle: in an app test target,
/// `Bundle.main` is the host app's bundle, not the test bundle.
private final class TestBundleToken {}

enum Fixture {
    struct NotFound: Error {
        let name: String
    }

    /// Loads a JSON fixture shipped with the test bundle.
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: TestBundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NotFound(name: name)
        }
        return try Data(contentsOf: url)
    }
}

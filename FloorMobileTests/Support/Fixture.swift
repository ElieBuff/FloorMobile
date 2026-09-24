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

    /// How many values the `enums` fixture holds, all entities and fields
    /// counted.
    ///
    /// Derived rather than written down: the backend adds a field whenever the
    /// product grows one, and a literal here fails on that growth instead of on
    /// a bug — which it has done twice.
    static func enumsValueCount() throws -> Int {
        // Spelled out rather than `EnumsPayload`, so this file needs no
        // `@testable import` of its own.
        let payload = try JSONDecoder().decode([String: [String: [String]]].self, from: data("enums"))
        return payload.values.reduce(0) { total, fields in
            total + fields.values.reduce(0) { $0 + $1.count }
        }
    }
}

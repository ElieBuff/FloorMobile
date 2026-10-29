//
//  JSONValueTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("JSON values")
struct JSONValueTests {

    @Test("Any JSON decodes, and encodes back to the same value", arguments: [
        #""VIP""#,
        "10000",
        "2.5",
        "true",
        "null",
        #"[1, "a", false]"#,
        #"{ "field": "note.salesAssociateId", "op": "eq", "value": { "param": "me" } }"#,
        #"{ "all": [{ "not": { "exists": "client.notes" } }, { "any": [] }] }"#,
    ])
    func roundTrip(json: String) throws {
        let value = try Self.decode(json)
        let encoded = try JSONEncoder().encode(value)

        // The same value read back, and the same structure as the JSON it came from.
        #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == value)
        #expect(try Self.object(encoded) == Self.object(Data(json.utf8)))
    }

    @Test("true and false stay booleans, 1 and 0 numbers")
    func booleansAreNotNumbers() throws {
        #expect(try Self.decode("true") == .bool(true))
        #expect(try Self.decode("false") == .bool(false))
        #expect(try Self.decode("1") == .number(1))
        #expect(try Self.decode("0") == .number(0))
    }

    // MARK: - Helpers

    private static func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    /// The JSON as Foundation reads it, to compare structures whatever the key order.
    private static func object(_ data: Data) throws -> NSObject? {
        try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? NSObject
    }
}

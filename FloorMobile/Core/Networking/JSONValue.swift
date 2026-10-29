//
//  JSONValue.swift
//  FloorMobile
//

import Foundation

/// Any JSON value, kept as it came: what the app carries without ever reading
/// it — a filter a sentence described (`client/text-filters`), whose condition
/// goes back whole to the search. It decodes any JSON and encodes the same
/// value back, its keys in any order, as JSON allows.
///
/// Not `Data`: an `Encodable` cannot write raw JSON into the list of filters a
/// search sends (`ClientFilterChoiceWire`). Not `JSONSerialization`'s `Any`:
/// neither `Sendable` nor `Hashable`, which the search options that will hold a
/// condition are (`ClientSearchOptions`). One type both ways, no `Request` and
/// `Response`: the value goes back as it came. A model may hold one — the one
/// exception to wire → model → view (floor-dev) — because the app never reads
/// it.
///
/// Numbers as `Double`: a condition's are amounts and counts, well within a
/// `Double`'s exact integers, and the server reads `10000` and `10000.0` alike.
nonisolated enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    /// `JSONDecoder` never reads a boolean as a number, nor a number as a
    /// boolean: each kind is tried in turn, and `booleansAreNotNumbers` holds
    /// the distinction.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string): try container.encode(string)
        case .number(let number): try container.encode(number)
        case .bool(let bool): try container.encode(bool)
        case .array(let array): try container.encode(array)
        case .object(let object): try container.encode(object)
        case .null: try container.encodeNil()
        }
    }
}

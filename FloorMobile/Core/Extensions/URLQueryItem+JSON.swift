//
//  URLQueryItem+JSON.swift
//  FloorMobile
//

import Foundation

nonisolated extension URLQueryItem {
    /// `value` as JSON, for a route that reads a structured parameter
    /// (`client/search`'s `filters`), its keys sorted: the same value always
    /// makes the same query, so a count reads like its search. `nil` if it
    /// does not encode.
    init?(name: String, json value: some Encodable) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(value) else { return nil }
        self.init(name: name, value: String(decoding: data, as: UTF8.self))
    }
}

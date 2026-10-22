//
//  URLQueryItem+JSON.swift
//  FloorMobile
//

import Foundation

nonisolated extension URLQueryItem {
    /// `value` as JSON, for a route that reads a structured parameter
    /// (`client/search`'s `filters`). `nil` if it does not encode.
    init?(name: String, json value: some Encodable) {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        self.init(name: name, value: String(decoding: data, as: UTF8.self))
    }
}

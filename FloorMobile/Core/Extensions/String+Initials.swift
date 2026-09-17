//
//  String+Initials.swift
//  FloorMobile
//

import Foundation

nonisolated extension String {
    /// Up to two initials of a person's name: "Elie Buff" → "EB", "Elie" → "E",
    /// "Marie-Charlotte Delestre" → "MD". Runs of whitespace are ignored; an
    /// empty or blank string yields an empty string. Uppercased so it reads
    /// the same whatever the source casing.
    var initials: String {
        split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }
}

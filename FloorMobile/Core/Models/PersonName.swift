//
//  PersonName.swift
//  FloorMobile
//

import Foundation

/// How a person's name reads in the app, whoever the person is — a client, a
/// sales associate, a search result: one rule, written once.
nonisolated enum PersonName {
    /// "Raphaël Van den Berg", "Raphaël", "Van den Berg", or `nil` when there
    /// is no name at all (both parts missing or blank).
    static func display(first: String?, last: String?) -> String? {
        let name = [first, last]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }
}

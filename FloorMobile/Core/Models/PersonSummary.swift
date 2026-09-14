//
//  PersonSummary.swift
//  FloorMobile
//

import Foundation

/// A person (client or sales associate) embedded in a `@Model` for display: a
/// value snapshot stored as a SwiftData composite attribute. Its members can't
/// be used in a `@Query` predicate — hoist a field to the model's top level to
/// filter or sort on it.
nonisolated struct PersonSummary: Codable, Sendable, Equatable {
    var id: String?
    var firstName: String?
    var lastName: String?
    var tier: String?

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var displayName: String? {
        let name = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    init(id: String? = nil, firstName: String? = nil, lastName: String? = nil, tier: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.tier = tier
    }

    init(dto: PersonDTO) {
        self.init(id: dto.id, firstName: dto.firstName, lastName: dto.lastName)
    }
}

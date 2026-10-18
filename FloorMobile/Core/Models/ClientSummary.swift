//
//  ClientSummary.swift
//  FloorMobile
//

import Foundation

/// A client embedded in a `@Model` for display: a value snapshot stored as a
/// SwiftData composite attribute (hence `Codable` — for the store, not the
/// network: it comes off the wire as a `ClientSummaryWire`). Richer than
/// `SalesAssociateSummary` (loyalty segment, external id, spend metrics). Its
/// members can't be used in a `@Query` predicate — hoist a field to the model's
/// top level to filter or sort on it.
nonisolated struct ClientSummary: Codable, Sendable, Equatable {
    var id: String?
    var externalId: String?
    var firstName: String?
    var lastName: String?
    var segment: String?
    var metrics: Metrics?

    nonisolated struct Metrics: Codable, Sendable, Equatable {
        var totalSpent12M: Decimal?
        var totalSpentLifetime: Decimal?
    }

    /// "Raphaël Van den Berg", "Raphaël", "Van den Berg", or `nil`.
    var displayName: String? {
        PersonName.display(first: firstName, last: lastName)
    }

    init(
        id: String? = nil,
        externalId: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        segment: String? = nil,
        metrics: Metrics? = nil
    ) {
        self.id = id
        self.externalId = externalId
        self.firstName = firstName
        self.lastName = lastName
        self.segment = segment
        self.metrics = metrics
    }

    init(wire: ClientSummaryWire) {
        self.init(
            id: wire.id,
            externalId: wire.externalId,
            firstName: wire.firstName,
            lastName: wire.lastName,
            segment: wire.segment,
            metrics: wire.metrics.map {
                Metrics(totalSpent12M: $0.totalSpent12M, totalSpentLifetime: $0.totalSpentLifetime)
            }
        )
    }
}

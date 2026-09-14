//
//  AgendaEndpoint.swift
//  FloorMobile
//

import Foundation

// MARK: - Agenda Endpoints

nonisolated extension Endpoint {
    /// The connected sales associate's event agenda — a fixed window around
    /// today (−1 month / +3 months) defined server-side, cursor-paginated.
    /// Pass the previous page's `nextCursor` as `after` to get the next page.
    static func eventAgenda(after cursor: String? = nil) -> Endpoint {
        Endpoint(
            path: "event/agenda",
            query: cursor.map { [URLQueryItem(name: "after", value: $0)] } ?? []
        )
    }
}

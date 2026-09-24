//
//  CursorPage.swift
//  FloorMobile
//

import Foundation

/// One page of a cursor-paginated Floor endpoint: `{ items, hasMore,
/// nextCursor }`. Generic so every paginated read (events, tasks, …) decodes
/// through the same envelope.
nonisolated struct CursorPage<Item: Decodable & Sendable>: Decodable, Sendable {
    var items: [Item]
    var hasMore: Bool
    var nextCursor: String?
}

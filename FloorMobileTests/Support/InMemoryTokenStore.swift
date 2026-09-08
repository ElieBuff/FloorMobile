//
//  InMemoryTokenStore.swift
//  FloorMobileTests
//

import Foundation
@testable import FloorMobile

/// In-memory `TokenStore` double. Also records call counts so tests can
/// assert how persistence was used (e.g. rotation saved exactly once).
final actor InMemoryTokenStore: TokenStore {
    private(set) var stored: TokenSet?
    private(set) var saveCount = 0

    func save(_ tokens: TokenSet) async throws {
        stored = tokens
        saveCount += 1
    }

    func load() async -> TokenSet? {
        stored
    }

    func clear() async throws {
        stored = nil
    }
}

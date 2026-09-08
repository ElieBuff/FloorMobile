//
//  TokenStore.swift
//  FloorMobile
//

import Foundation

/// Persistence boundary for tokens.
///
/// The real implementation targets the Keychain; unit tests substitute an
/// in-memory store — the Keychain is never touched by a unit test.
nonisolated protocol TokenStore: Sendable {
    func save(_ tokens: TokenSet) async throws
    func load() async -> TokenSet?
    func clear() async throws
}

//
//  SingleExpansion.swift
//  FloorMobile
//

import Foundation

/// Single-open accordion state: opening one row closes any other. A general
/// UI-interaction helper (not tied to a specific screen), kept as a pure value
/// type so the one-open-at-a-time rule is unit-testable without any view.
nonisolated struct SingleExpansion<ID: Hashable> {
    private(set) var openID: ID?

    func isOpen(_ id: ID) -> Bool { openID == id }

    /// Tapping the open row closes it; tapping another switches to it.
    mutating func toggle(_ id: ID) {
        openID = (openID == id) ? nil : id
    }
}

//
//  Loadable.swift
//  FloorMobile
//

import Foundation

/// Where one asked-for value stands: on its way, there, or failed.
///
/// Not an `Optional`: a `nil` would mean both "on its way" and "failed",
/// while a screen shows a spinner for one and a message — or nothing — for
/// the other. Kept for each value a screen asks for on its own: the parts of
/// a client's profile (`ClientProfile`), the total of "Filter"
/// (`ClientFilterEditor`).
nonisolated enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed(any Error)

    /// The value once loaded, `nil` otherwise.
    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }

    /// Why the value could not be loaded, `nil` otherwise.
    var error: (any Error)? {
        if case .failed(let error) = self { error } else { nil }
    }

    /// Whether the value is on its way.
    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}

extension Loadable: Sendable where Value: Sendable {}

//
//  HomeRoute.swift
//  FloorMobile
//

import Foundation

/// The screens the Home tab can push. Navigation is value-based: a screen
/// pushes one of these, and the Home `NavigationStack` maps it to a view in
/// its `navigationDestination(for: HomeRoute.self)`.
///
/// A route carries identifiers and plain values only — never a model object,
/// a view or a closure — so it survives a relaunch, a cache refresh or a
/// model mutation, and stays `Codable` for state restoration and deep links.
nonisolated enum HomeRoute: Hashable, Codable {
    /// The agenda, opened on a given day.
    case agenda(date: Date)
}

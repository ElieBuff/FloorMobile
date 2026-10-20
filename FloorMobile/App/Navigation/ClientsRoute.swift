//
//  ClientsRoute.swift
//  FloorMobile
//

import Foundation

/// The screens the Clients tab can push. Navigation is value-based: a row
/// pushes one of these, and the Clients `NavigationStack` maps it to a view in
/// its `navigationDestination(for: ClientsRoute.self)` (`MainTabView`).
///
/// A route carries identifiers only — never a model object, nor the value a
/// list built — so it survives a relaunch, a sync or a search that moves on,
/// and stays `Codable` for state restoration and deep links, like `HomeRoute`.
nonisolated enum ClientsRoute: Hashable, Codable {
    /// A client's profile, by the server's id: any client of the brand,
    /// whichever list it was opened from.
    case profile(id: String)
}

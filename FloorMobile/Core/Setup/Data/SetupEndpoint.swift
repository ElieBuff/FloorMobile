//
//  SetupEndpoint.swift
//  FloorMobile
//

import Foundation

nonisolated extension Endpoint {
    /// The app's configuration, one block per subject: the values of the
    /// pickers (`enums`) and the tenant's "My Clients" filters. Small, read
    /// whole at launch: no pagination.
    ///
    /// The BFF also expects it read again when `client/search` answers 409
    /// `filters_changed` (the tenant changed its filters) — not wired yet: the
    /// app sends no filter so far.
    static func setup() -> Endpoint {
        Endpoint(path: "setup")
    }
}

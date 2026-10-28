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
    /// The BFF also expects it read again when `client/search` or
    /// `client/count` answers 409 `filters_changed` (the tenant changed its
    /// filters). The app deliberately does not: the case is too rare to be
    /// worth the code. "Apply" then goes without a number, "My Clients" shows
    /// "Search failed", and the next launch brings the filters back in line.
    static func setup() -> Endpoint {
        Endpoint(path: "setup")
    }
}

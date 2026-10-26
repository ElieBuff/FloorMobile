//
//  ClientSearchScope.swift
//  FloorMobile
//

import Foundation

/// Whose clients a search looks among: the Clients tab's two lists, and what
/// `Endpoint.searchClients` asks the server for.
nonisolated enum ClientSearchScope: CaseIterable, Sendable {
    /// The associate's own clients — "My Clients", on the server or on the
    /// device (`MyClientsList`).
    case mine
    /// Any client of the brand — "All Brand", on the server.
    case brand

    /// The scope's name in the Clients tab's picker.
    var title: String {
        switch self {
        case .mine: String(localized: "My Clients")
        case .brand: String(localized: "All Brand")
        }
    }
}

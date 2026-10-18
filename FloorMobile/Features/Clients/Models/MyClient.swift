//
//  MyClient.swift
//  FloorMobile
//

import Foundation

/// One of the associate's own clients, found by a search on the server: what
/// the "My Clients" list shows of them while the server answers.
///
/// `Client`'s counterpart for a search result: the server finds them, typos
/// and all, among the associate's own clients — their store's today — and the
/// device shows them without keeping them. A plain value, so it lives only as
/// long as the search that found it. The email and the phone come with it:
/// the server sends them for the associate's own clients only.
nonisolated struct MyClient: Identifiable, Sendable, Equatable {
    let id: String
    /// "Raphaël Van den Berg", or `nil` when the server has no name.
    let displayName: String?
    let primaryEmail: String?
    let primaryPhone: String?
}

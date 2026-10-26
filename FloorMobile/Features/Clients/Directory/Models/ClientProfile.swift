//
//  ClientProfile.swift
//  FloorMobile
//

import Foundation

/// A client's profile as the server holds it, asked for each time the
/// associate opens it: what the profile page shows.
///
/// The server sends everything it has on the client (`client/{id}`); the app
/// keeps what the page shows — today the client's card — and grows section by
/// section as the profile is designed. A plain value, never stored: any client
/// of the brand can be opened, while the device keeps only its store's.
nonisolated struct ClientProfile: Identifiable, Sendable, Equatable {
    /// The client's card: who they are, where they belong, how to reach them.
    let client: ClientItem

    var id: String { client.id }
}

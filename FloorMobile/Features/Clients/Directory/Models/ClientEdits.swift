//
//  ClientEdits.swift
//  FloorMobile
//

import Foundation
import Observation

/// The clients edited while the client list is on screen, so it shows an
/// edit without searching again: each row reads `current(_:)` rather than
/// the card its page holds.
///
/// Lives only as long as those pages: a new search reads the server, which
/// has the edit already, so the list calls `removeAll()` when it asks for a
/// first page, whatever started it: a text, a sort or a filter, "Try again".
/// An edit never hides what changed elsewhere since (the console, the
/// ingestion, a reassignment).
///
/// A type rather than a callback: the profile is a route's destination, and
/// a route carries no closure — the list that pushed it cannot be called
/// back. Held by `ClientsView`, above the list and the profiles it opens,
/// and handed to each: the profile records, the list reads.
@Observable
final class ClientEdits {
    /// The saved cards, by client id.
    private var saved: [String: ClientItem] = [:]

    /// Keeps the card the server answered an edit with, in place of any
    /// earlier one.
    func record(_ client: ClientItem) {
        saved[client.id] = client
    }

    /// The card to show: the one saved by an edit, else `client` as the page
    /// holds it.
    func current(_ client: ClientItem) -> ClientItem {
        saved[client.id] ?? client
    }

    /// Forgets every edit — a new search brings them from the server.
    func removeAll() {
        saved.removeAll()
    }
}

//
//  RecentClients.swift
//  FloorMobile
//

import Foundation
import Observation

/// The associate's recent clients — the last they viewed, the latest first —
/// which the client list's search field shows as soon as it is touched,
/// until three characters are typed.
///
/// Kept in memory by `ClientsView`, never in the store (decision of 15/11),
/// and asked again each time the list comes back on screen (`refresh`):
/// coming back from a profile, the server has its view — that client first —
/// and any edit made there.
@Observable
final class RecentClients {
    /// The recent clients, the latest viewed first; `nil` until they first
    /// come — and while they do not, the field shows the list as before.
    private(set) var clients: [ClientItem]?
    /// Whether a request is on its way, so a second one does not start.
    private var isLoading = false

    /// Asks the server for the recent clients (`ClientService.recentClients`)
    /// and takes them in place of those held, which stay on screen until
    /// then — unless a request is already on its way. A failure is ignored
    /// (decision of 15/11): the clients held stay, and the next call asks
    /// again.
    ///
    /// A profile closed within a second of opening may come back before its
    /// view has reached the server: that client is then first the next time.
    func refresh(session: AppSession, services: AppServices) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if let clients = try? await services.clients.recentClients(using: session.api) {
            self.clients = clients
        }
    }
}

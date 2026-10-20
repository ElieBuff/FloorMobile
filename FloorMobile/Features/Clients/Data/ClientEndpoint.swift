//
//  ClientEndpoint.swift
//  FloorMobile
//

import Foundation

// MARK: - Client Endpoints

nonisolated extension Endpoint {
    /// The connected associate's store clients: all of them without a cursor,
    /// then only those changed since it. The store comes from the token, never
    /// from the request.
    ///
    /// Pass the previous page's `nextCursor` as `after` to get the next page —
    /// and, once a pass is over, its last page's `nextCursor` to get only what
    /// changed since (see `ClientService.synchronize(using:cursor:)`).
    static func clientSync(after cursor: String? = nil) -> Endpoint {
        Endpoint(path: "client/sync", query: after(cursor))
    }

    /// Every client id of the connected associate's store, all at once: the
    /// route's filters left out, which is what makes it the whole list.
    static let storeClientIDs = Endpoint(path: "client/filter")

    /// The fewest characters, spaces aside, a client search sends: the server
    /// refuses fewer. Below it, "All Brand" asks for more and "My Clients"
    /// searches the device.
    static let clientSearchMinimumLength = 3

    /// The associate's own clients whose name, email or phone matches
    /// `query` — the closest first, 50 a page, each with their email and
    /// phone. Whose clients they are is the server's to set (their store
    /// today, from the token): the app only says `scope=mine`. Interactive:
    /// the associate waits on it, so it fails fast and the list falls back on
    /// the device.
    static func searchMyClients(_ query: String, after cursor: String? = nil) -> Endpoint {
        Endpoint(
            path: "client/search",
            query: [URLQueryItem(name: "scope", value: "mine"), URLQueryItem(name: "q", value: query)]
                + after(cursor),
            interactive: true
        )
    }

    /// Any client of the brand whose name, email or phone matches `query` —
    /// the closest first, 50 a page. Never sent with fewer than
    /// `clientSearchMinimumLength` characters, which the server refuses.
    static func searchBrandClients(_ query: String, after cursor: String? = nil) -> Endpoint {
        Endpoint(
            path: "client/search",
            query: [URLQueryItem(name: "q", value: query)] + after(cursor)
        )
    }

    /// Everything the server holds on one client of the brand: the profile
    /// page's source (`ClientProfileWire`). Interactive: the associate waits on
    /// it, so without a connection it fails at once and the page offers to try
    /// again.
    static func clientProfile(id: String) -> Endpoint {
        Endpoint(path: "client/\(id)", interactive: true)
    }

    /// Records that the connected associate opened this client's profile: one
    /// line in the server's views journal, at the server's time. Answers with
    /// the recent clients as they now stand — `recentClients`' list, this
    /// client first.
    ///
    /// Interactive although no one waits on its answer: the route forbids
    /// queuing a view offline — a view made without network is lost, by
    /// decision. The default session would wait for the network and send it
    /// hours later, dated by the server when it arrives; interactive, it fails
    /// at once without a connection, and after a few seconds of a silent
    /// server.
    static func recordClientView(id: String) -> Endpoint {
        Endpoint(path: "client/\(id)/view", method: .post, interactive: true)
    }

    /// The associate's last viewed clients, each once, the latest view first —
    /// as many as the server keeps, its call alone. The device refreshes its
    /// copy (`RecentClient`) from it at launch; after a view, the answer to
    /// `recordClientView` carries the same list.
    static let recentClients = Endpoint(path: "client/recent")

    /// `after` when there is a cursor to send, nothing otherwise.
    private static func after(_ cursor: String?) -> [URLQueryItem] {
        cursor.map { [URLQueryItem(name: "after", value: $0)] } ?? []
    }
}

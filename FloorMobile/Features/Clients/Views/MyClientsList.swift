//
//  MyClientsList.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "My Clients": the associate's own clients matching the search — their
/// store's today, as the server sets it.
///
/// Where the matches come from depends on the search, spaces around it aside,
/// and on the sort and filters picked (`options`) — see `usesServer`:
/// - below `Endpoint.clientSearchMinimumLength` characters with nothing
///   picked, the device: the store's clients as the startup sync keeps them,
///   by last name then first name, narrowed to those that match
///   (`Client.matching`) — instant, and all of them while nothing is typed;
/// - from there on, or as soon as a sort or a filter is picked — the device
///   can apply neither — the server (`ClientService.searchClients`, `.mine`),
///   typos and all, closest first, a page at a time (`PagedSearchList`). A
///   text too short for the server is not sent: the clients then come in the
///   sort's order;
/// - when the server fails that first page — an error, no connection, a
///   server that stays silent — the device again, for the same text, under a
///   notice that says so. The request is interactive (`Endpoint.interactive`):
///   without a connection it fails as soon as the typing pauses, with a
///   silent server once `APIClient`'s short timeout runs out.
///
/// The sort and the filters are picked in `ClientSearchControls`' sheets, over
/// the list. They are this list's: a trip to "All Brand" rebuilds it, and
/// starts them over.
///
/// The fallback lasts one text: every new text asks the server first, and so
/// does the notice's "Try again". A next page that fails keeps the server's
/// pages on screen and raises the alert "All Brand" raises — the notice
/// speaks of results from this device, which those are not.
///
/// The device's list is the store's, as the sync keeps it: it stands in for
/// the server's "mine" only while "mine" is the store — a tenant that narrows
/// "mine" to the associate's own book needs the sync narrowed with it. It
/// loads a page at a time: SwiftData filters and sorts, and hands back only
/// the first `limit` matches; `limit` grows as the associate nears the end of
/// what is loaded. A store of tens of thousands of clients costs what is on
/// screen, not the whole book.
struct MyClientsList: View {
    let query: String

    /// The sort and the filters picked, as the server's search sends them.
    @State private var options = ClientSearchOptions()

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services

    /// How many of the device's matches to load, grown a page at a time.
    @State private var limit = Self.pageSize
    /// The text whose first page the server failed: while it is still the
    /// text, the device's matches stand in for the server's. A text rather
    /// than a flag, so a failure reported late for an earlier text never
    /// reaches a later one.
    @State private var unansweredText: String?
    @State private var alert: FloorAlert?
    /// Whether the store has any client at all — one row is enough to know.
    @Query(firstClientDescriptor) private var anyClient: [Client]

    private static let pageSize = 50

    private static var firstClientDescriptor: FetchDescriptor<Client> {
        var descriptor = FetchDescriptor<Client>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// The search as both sources get it, spaces around it aside.
    private var text: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the server answers rather than the device: a text long enough
    /// for it, or a sort or a filter picked, which the device cannot apply.
    static func usesServer(text: String, options: ClientSearchOptions) -> Bool {
        text.count >= Endpoint.clientSearchMinimumLength || !options.isDefault
    }

    var body: some View {
        VStack(spacing: 0) {
            ClientSearchControls(options: $options)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            content
        }
            // A new text, or a new sort or filter, asks the server first
            // again, starts the device's list from its first page, and drops
            // an alert about the last one. On the trimmed text, so a space
            // typed after a word changes nothing.
            .onChange(of: text) { reset() }
            .onChange(of: options) { reset() }
            .floorAlert($alert)
    }

    private func reset() {
        unansweredText = nil
        limit = Self.pageSize
        alert = nil
    }

    /// The device's matches below the server's minimum, and under the notice
    /// while they stand in for its results; the server's results otherwise.
    /// Separate branches, so moving between them builds the list afresh:
    /// falling back drops the server's list, and "Try again" builds a new one,
    /// which asks for the first page again.
    @ViewBuilder
    private var content: some View {
        if !Self.usesServer(text: text, options: options) {
            deviceMatches
        } else if unansweredText == text {
            // Above the list rather than over it: the card is translucent, and
            // rows scrolling under it would bury its message.
            VStack(spacing: 0) {
                fallbackNotice
                    .padding(.top, 8)
                deviceMatches
            }
        } else {
            PagedSearchList(query: text, filters: options) { text, cursor in
                // A text too short for the server is left out: the sort alone orders.
                let query = text.count >= Endpoint.clientSearchMinimumLength ? text : nil
                return try await services.clients.searchClients(
                    query, in: .mine, options: options, after: cursor, using: session.api
                )
            } onFailure: { failure in
                if failure.isFirstPage {
                    // Nothing of the server's on screen yet: the device stands in.
                    unansweredText = failure.query
                } else {
                    // The server's pages stay; the alert fetches the one that failed.
                    alert = failure.alert
                }
            } row: { client in
                NavigationLink(value: ClientsRoute.profile(id: client.id)) {
                    ClientRow(client: client, display: .mine)
                }
            }
        }
    }

    /// The device's copy of the store's clients, narrowed to the search — or,
    /// while the device holds none, only the word that the sync brings them.
    @ViewBuilder
    private var deviceMatches: some View {
        if anyClient.isEmpty {
            ContentUnavailableView(
                String(localized: "No clients yet"),
                systemImage: "person.2",
                description: Text("Your store's clients appear here once they are synchronized.")
            )
        } else {
            MatchingClients(query: text, limit: limit) {
                limit += Self.pageSize
            }
        }
    }

    /// Says the list comes from the device because the server did not answer,
    /// and offers to ask it again.
    private var fallbackNotice: some View {
        EmptySectionCard(
            icon: {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(Color(.OnCanvas.textPrimary))
                    // The message says what happened — and a silent server is
                    // not a missing connection.
                    .accessibilityHidden(true)
            },
            message: String(localized: "Online search isn't responding. Showing results from this device."),
            action: EmptySectionAction(label: String(localized: "Try again")) {
                unansweredText = nil
            }
        )
        // One element for VoiceOver: the message, then its button, labelled by
        // its visible "Try again".
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 16)
    }
}

/// The first `limit` clients matching `query`. A view of its own because a
/// `@Query` is fixed when its view is built: changing the query or the limit
/// builds a new one.
private struct MatchingClients: View {
    let query: String
    let limit: Int
    /// Asked for more as the end of what is loaded comes into view.
    let onNearEnd: () -> Void

    @Query private var clients: [Client]

    init(query: String, limit: Int, onNearEnd: @escaping () -> Void) {
        self.query = query
        self.limit = limit
        self.onNearEnd = onNearEnd
        var descriptor = FetchDescriptor(
            predicate: Client.matching(query),
            sortBy: [SortDescriptor(\.lastName), SortDescriptor(\.firstName)]
        )
        descriptor.fetchLimit = limit
        _clients = Query(descriptor)
    }

    var body: some View {
        List(clients) { client in
            NavigationLink(value: ClientsRoute.profile(id: client.id)) {
                ClientRow(client: ClientItem(client: client), display: .mine)
            }
            .listRowInsets(.cardRow)
            .onAppearNearEnd(of: clients, item: client) {
                // Fewer than asked for means the store has no more.
                if clients.count == limit {
                    onNearEnd()
                }
            }
        }
        .cardList()
        .overlay {
            if clients.isEmpty, !query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

// MARK: - Previews

// The server's search reads the session and the services, injected at the
// root in the app — so the previews hand them over too, though they stay
// below three characters and never ask.
#Preview("On the device") {
    let container = try! ModelContainer(
        for: Client.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(Client(
        id: "1", externalId: "1", firstName: "Alice", lastName: "Martinez",
        primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
    ))
    container.mainContext.insert(Client(
        id: "2", externalId: "2", firstName: "Raphaël", lastName: "Van den Berg",
        primaryPhone: "+33 6 98 76 54 32"
    ))
    return MyClientsList(query: "")
        .ambientBackground()
        .modelContainer(container)
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
}

#Preview("No clients yet") {
    let container = try! ModelContainer(
        for: Client.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return MyClientsList(query: "")
        .ambientBackground()
        .modelContainer(container)
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: container))
}

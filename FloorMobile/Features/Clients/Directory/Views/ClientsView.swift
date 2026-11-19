//
//  ClientsView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// The Clients tab: the associate's own clients — their store's today, as the
/// server sets it — under the large title "All my clients", how many they
/// are below it, and the header's three buttons.
///
/// The subtitle's totals are the server's alone (decision of 18/11), never
/// the device's count: the associate's own (`bookTotal`), asked on entry
/// (`client/count`), and the filters' (`filteredTotal`), which "Sort &
/// filter" hands back with them on "Show" — it has just counted it — rather
/// than the list asking again (`show`). Nothing shows until the server has
/// answered.
///
/// The server answers first (`ClientService.searchClients`, `.mine`), with the
/// sort and the filters picked in "Sort & filter" (`options`), a page at a
/// time (`PagedSearchList`), each client a `ClientRow` — and with
/// the name typed in the search field, under the title. Touched, the field
/// shows the associate's recent clients instead, until three characters are
/// typed (`showsRecents`, `RecentClients`).
///
/// When the server fails the first page without a connection, with no filter
/// picked and no text typed, the device's clients stand in, under a notice
/// that says so (`showsDevice`); otherwise the failure itself
/// (`LoadFailureView`). The request is interactive (`Endpoint.interactive`):
/// without a connection it fails as soon as it is sent, with a silent server
/// once `APIClient`'s short timeout runs out.
///
/// The fallback, or the failure, lasts one search: every new sort or filter
/// asks the server first, and so does their "Try again". A next page that
/// fails keeps the pages on screen under the list's own alert
/// (`PagedSearchList`).
///
/// What the server first costs (decision of 12/11): opening the tab shows a
/// spinner until the server answers, where the device's list showed at once;
/// and the device's list, read a page at a time (`Client.page`), does not
/// follow the store live — nothing writes it while the list is on screen but
/// an edit from a profile, which `ClientEdits` shows.
///
/// The device's list is the store's, as the sync keeps it: it stands in for
/// the server's "mine" only while "mine" is the store — a tenant that narrows
/// "mine" to the associate's own book needs the sync narrowed with it.
struct ClientsView: View {
    /// The fewest characters, spaces aside, a search sends to the server,
    /// which refuses fewer: below it, the server is asked without the text.
    static let searchMinimumLength = 3
    /// How many of the device's clients a page holds, without a connection.
    private static let devicePageSize = 50
    /// What an empty list says when nothing narrows it, from either source.
    private static let noClients = (title: String(localized: "No clients yet"), systemImage: "person.2")

    /// What the search field holds. The field sits under the title and folds
    /// away as the list scrolls (decision of 15/11): it searches a name inside
    /// the list on screen, with its sort and its filters, where the Search tab
    /// searches everything. Only the server reads the text: the device does
    /// not search (decision of 12/11).
    @State private var query = ""
    /// Whether the search field is active: touched, risen into the bar, until
    /// "Cancel".
    @State private var isSearching = false
    /// The associate's recent clients, which the active field shows until
    /// three characters are typed — asked each time the list comes on screen.
    @State private var recents = RecentClients()

    /// The clients edited from a profile this tab opened, which the list
    /// shows over its pages until their next search: here, above the list and
    /// the profiles it opens.
    @State private var edits = ClientEdits()
    /// The sort and the filters picked, as the server's search sends them:
    /// written by "Sort & filter"'s "Show" (`ClientSortFilterView`), opened
    /// by the bar's button.
    @State private var options = ClientSearchOptions()
    /// Whether "Sort & filter" is open.
    @State private var isSortingAndFiltering = false
    /// The first page the server failed, while its text is still the search:
    /// the device's clients stand in for the server's, or the error does
    /// (`showsDevice`). Its text, not a flag, says which search failed, so a
    /// failure reported late for an earlier text never reaches a later one.
    @State private var failedSearch: (query: String, error: any Error)?
    /// How many clients the associate has: the server's total without a
    /// filter (`client/count`), for the subtitle. Asked when the list comes
    /// on screen until it is known, then handed again by a "Show" without
    /// filters; `nil` until the server answers.
    @State private var bookTotal: Int?
    /// How many clients the filters picked keep, for the subtitle: handed by
    /// "Show" with them; `nil` without filters, and while not counted.
    @State private var filteredTotal: Int?
    /// The brand's segments, as `GET setup` stored them on the device at
    /// launch — read here, never fetched: each row's tag takes its client's.
    @Query(sort: \ClientSegment.rank) private var segments: [ClientSegment]

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext

    /// The text the search sends: the field's, spaces around it aside, once it
    /// is long enough for the server — empty until then, so the first letters
    /// typed do not start the list over for nothing.
    private var text: String {
        Self.searchText(typed: query)
    }

    /// What the server is sent of the text typed in the field: the text
    /// without the spaces around it, or nothing while it is shorter than
    /// `searchMinimumLength`.
    static func searchText(typed: String) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= searchMinimumLength ? trimmed : ""
    }

    /// Whether the recent clients stand in for the list: the field is active,
    /// fewer than `searchMinimumLength` characters are typed, and there are
    /// recent clients to show — without any, the list shows as before.
    static func showsRecents(isSearching: Bool, typed: String, recents: [ClientItem]?) -> Bool {
        isSearching && searchText(typed: typed).isEmpty && !(recents ?? []).isEmpty
    }

    /// Whether a first page the server failed gives way to the device's
    /// clients: only without a connection — `AppError.network`: none, or a
    /// server silent past `APIClient`'s short timeout — and with neither a
    /// text nor filters, which the device cannot apply. Any other error shows
    /// as it is: after a 503 `search_timeout`, the BFF asks not to fall back
    /// silently on the device. A sort alone lets the device stand in, by
    /// name, without the sort: the notice already says the list comes from
    /// the device.
    static func showsDevice(after error: any Error, text: String, options: ClientSearchOptions) -> Bool {
        guard case .network? = error as? AppError else { return false }
        return text.isEmpty && options.filters.isEmpty
    }

    var body: some View {
        content
            // A new text, or a new sort or filter, asks the server first again.
            // On the text as sent, so a space typed after a word changes nothing.
            .onChange(of: text) { reset() }
            .onChange(of: options) { reset() }
            .ambientBackground()
            .navigationTitle("All my clients")
            .toolbarTitleDisplayMode(.large)
            .navigationSubtitle(
                Self.subtitle(bookTotal: bookTotal, filteredTotal: filteredTotal, isFiltered: !options.filters.isEmpty)
            )
            // In the navigation bar's drawer: under the large title at the top
            // of the list, folded away as it scrolls — iOS shows it whenever
            // the list is at its top. The default placement shows no field at
            // all beside the Search tab, and none hides it at rest short of a
            // magnifier in the bar (measured on iOS 27.2, 15/11).
            .searchable(
                text: $query,
                isPresented: $isSearching,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text("Search")
            )
            .toolbar { headerButtons }
            // Full screen, not a sheet (decision of 18/11): closed by its
            // cross or by "Show", never by a swipe down, which would drop the
            // filters being picked. Its two sheets — "Voice search", "Your
            // description" — open over it at half height.
            .fullScreenCover(isPresented: $isSortingAndFiltering) {
                ClientSortFilterView(options: options, onShow: show)
            }
            // The associate's total, asked on entry (decision of 18/11), and
            // on a later appearance only while it is still unknown.
            .task {
                guard bookTotal == nil, let total = await countClients(matching: []) else { return }
                bookTotal = total
            }
            .onAppear {
                // Back from a profile, the server has its view, that client
                // first. In a task of its own rather than `.task`, which the
                // list leaving would cancel: the answer is kept for later.
                Task { await recents.refresh(session: session, services: services) }
            }
            // On the stack's root content, never inside a lazy container (List,
            // LazyVStack), where it might never register — and here rather than
            // in `MainTabView`, so the profile gets the edits the list reads.
            .navigationDestination(for: ClientsRoute.self) { route in
                switch route {
                case .profile(let id, let card):
                    ClientProfileView(clientID: id, card: card, edits: edits)
                }
            }
    }

    private func reset() {
        failedSearch = nil
    }

    // MARK: - Header

    /// The header's three buttons, each in its own glass: "‹ Lists" where a
    /// back button goes, sort-and-filter — under the number of filters
    /// picked — and add at the other end.
    @ToolbarContentBuilder
    private var headerButtons: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // Where a back button goes, as the mockup draws it (15/11,
            // `C-Liste-Sous-Lists`): the list sits one step under the Lists
            // screen. No action yet (decision of 12/11): the saved lists' plan
            // gives it one — the Lists screen then pushes this list, and iOS's
            // own back button takes this one's place.
            Button {} label: {
                // A view of its own: in a bar, a `Label` shows its icon only.
                // The back chevron, then 10.6 pt before the title, as the
                // mockup draws them.
                HStack(spacing: 10.6) {
                    Image(systemName: "chevron.backward")
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                    Text("Lists")
                }
            }
            .barButtonStyle()
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isSortingAndFiltering = true
            } label: {
                // A view of its own, as for "Lists": the bar draws a plain
                // icon at its own size, whatever its font or scale.
                HStack { Image(systemName: "slider.horizontal.3") }
            }
            .accessibilityLabel(String(localized: "Sort and filter"))
            // How many filters are picked, in iOS's own badge: none at zero,
            // and VoiceOver reads the count after the label. Red, where the
            // mockup draws it in ink (`C-ListeFiltree`): no SwiftUI setting
            // recolours it (tried on iOS 27.2), and an ink one needs the
            // button to draw its own glass — for later (decision of 19/11).
            .badge(options.filters.count)
            .barButtonStyle()
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            // No action yet (decision of 12/11): the client creation's plan gives it one.
            Button {} label: {
                HStack { Image(systemName: "plus") }
            }
            .accessibilityLabel(String(localized: "Add a client"))
            .barButtonStyle()
        }
    }

    /// The subtitle, from the server's totals alone: "42 in your book" without
    /// filters, as the mockup writes it (`C-Liste`), "12 of 42 clients" with
    /// them — nothing until the totals it needs are known, and for an empty
    /// book. With filters, the mockup writes "12 clients" (`C-ListeFiltree`)
    /// over the filters' pills: the list shows no pills (decision of 18/11),
    /// so the subtitle says itself that the list is filtered — "0 of 42
    /// clients" when the filters keep no one. Neither counts the list's
    /// text: the totals speak of the book and of the filters, not of a name
    /// searched.
    static func subtitle(bookTotal: Int?, filteredTotal: Int?, isFiltered: Bool) -> String {
        guard let bookTotal, bookTotal > 0 else { return "" }
        guard isFiltered else { return String(localized: "\(bookTotal) in your book") }
        guard let filteredTotal else { return "" }
        return String(localized: "\(filteredTotal) of \(bookTotal) clients")
    }

    /// What "Show" hands back from "Sort & filter": the sort and the filters,
    /// and their total when the screen had it — the list does not ask the
    /// server again for a total just counted (decision of 18/11). Without
    /// filters, that total is the associate's own. With filters and no total
    /// — "Show" touched before its count came back, or after one that failed
    /// —, it is asked once, here: no second try, a failure leaves the
    /// subtitle empty until the next "Show".
    private func show(_ shown: ClientSearchOptions, total: Int?) {
        options = shown
        guard !shown.filters.isEmpty else {
            filteredTotal = nil
            if let total { bookTotal = total }
            return
        }
        filteredTotal = total
        guard total == nil else { return }
        // In a task of its own, as the recents': the list leaving for a
        // profile must not cancel it.
        Task {
            let counted = await countClients(matching: shown.filters)
            // Only for the filters still on the list.
            if options.filters == shown.filters { filteredTotal = counted }
        }
    }

    /// The server's total for `filters`, without the list's text; `nil` on
    /// any failure: a total is a hint, the subtitle goes without it.
    private func countClients(matching filters: [ClientFilterChoice]) async -> Int? {
        try? await services.clients.countClients(nil, filters: filters, using: session.api)
    }

    // MARK: - List

    /// The server's clients — or, once it failed their first page, the
    /// device's under the notice, or the error (`showsDevice`). Separate
    /// branches, so moving between them builds the list afresh: "Try again"
    /// builds a new one, which asks the server for its first page again.
    @ViewBuilder
    private var content: some View {
        if Self.showsRecents(isSearching: isSearching, typed: query, recents: recents.clients) {
            recentClients
        } else if let failedSearch, failedSearch.query == text {
            if Self.showsDevice(after: failedSearch.error, text: text, options: options) {
                // Above the list rather than over it: the card is translucent,
                // and rows scrolling under it would bury its message.
                VStack(spacing: 0) {
                    fallbackNotice
                        .padding(.top, 8)
                    deviceClients
                }
            } else {
                failedFirstPage(failedSearch.error)
            }
        } else {
            serverClients
        }
    }

    /// The server's clients for the search, in the sort's order; a sort or a
    /// filter picked starts them over from their first page.
    private var serverClients: some View {
        PagedSearchList(query: text, restartingOn: options, emptyLabel: emptyServerResults) { text, cursor in
            // A first page reads a server that has every edit already (`ClientEdits`).
            if cursor == nil { edits.removeAll() }
            // Without a text, the sort alone orders.
            return try await services.clients.searchClients(
                text.isEmpty ? nil : text, options: options, after: cursor, using: session.api
            )
        } onFirstPageFailure: { query, error in
            // Nothing of the server's on screen yet: the device stands in, or
            // the error does.
            failedSearch = (query, error)
        } row: { clientLink($0) }
    }

    /// The recent clients, under "Recent", in the list's look, each opening
    /// its profile. Not `.searchSuggestions`, Apple's tool for what shows when
    /// a field is touched: a suggestion reacts to a tap only by filling the
    /// text (`searchCompletion`), never by opening a profile, and shows in the
    /// system's list rather than this one. Leaving them by "Cancel" builds the
    /// list afresh, its first page asked again — as erasing a text does.
    private var recentClients: some View {
        List {
            Section {
                ForEach(recents.clients ?? []) { client in
                    clientLink(client)
                        .insetGroupedRow()
                }
            } header: {
                Text("Recent")
                    .textCase(nil)
            }
        }
        .insetGroupedList()
    }

    /// The store's clients, by name, as the sync keeps them — no sort, no
    /// filter. A store that cannot be read (very rare) leaves the list empty
    /// under the notice, without saying why: too rare for code.
    private var deviceClients: some View {
        PagedSearchList(query: "", emptyLabel: Self.noClients) { _, cursor in
            // The store has every edit already (`Client.apply`).
            if cursor == nil { edits.removeAll() }
            return try Client.page(after: cursor, size: Self.devicePageSize, in: modelContext)
        } onFirstPageFailure: { _, _ in } row: { clientLink($0) }
    }

    /// A client's row, opening their profile, with any edit saved since its
    /// page came (`ClientEdits`) — here and in the profile — and the brand's
    /// segment its client's `segment` names: the same code, as the server
    /// writes both.
    private func clientLink(_ received: ClientItem) -> some View {
        let client = edits.current(received)
        return NavigationLink(value: ClientsRoute.profile(id: client.id, card: client)) {
            ClientRow(client: client, segment: ClientSegment.named(client.segment, in: segments))
        }
        // No chevron: the mockup's rows have none. Here, not in `.insetGroupedList()`,
        // whose forms keep theirs (`FormPushRow`).
        .navigationLinkIndicatorVisibility(.hidden)
    }

    /// What an empty first page of the server's says, without a text: the
    /// filters matched no one, or — a sort alone — there is no client.
    private var emptyServerResults: (title: String, systemImage: String) {
        options.filters.isEmpty
            ? Self.noClients
            : (String(localized: "No clients match these filters"), "line.3.horizontal.decrease")
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
                failedSearch = nil
            }
        )
        // One element for VoiceOver: the message, then its button, labelled by
        // its visible "Try again".
        .accessibilityElement(children: .combine)
        // In line with the list below it (`.insetGroupedList()`'s margin).
        .padding(.horizontal, AppSpacing.screenInset)
    }

    /// What went wrong with a first page the device does not stand in for.
    /// For any network error, which `showsDevice` leaves here only with
    /// filters picked or a text typed — no connection, or a server silent past
    /// `APIClient`'s short timeout, which `AppError.network` does not tell
    /// apart: "Filters need a connection", or "Search needs a connection" for
    /// a text alone. "Search failed" otherwise. And "Try again", which builds
    /// the list afresh, so it asks for that first page again.
    private func failedFirstPage(_ error: any Error) -> some View {
        let title = if case .network? = error as? AppError {
            options.filters.isEmpty
                ? String(localized: "Search needs a connection")
                : String(localized: "Filters need a connection")
        } else {
            String(localized: "Search failed")
        }
        return LoadFailureView(title: title, error: error) {
            failedSearch = nil
        }
    }
}

// MARK: - Previews

// The preview's API client aims at a host that does not answer: the first
// page fails as without a connection, and the device's clients stand in.
// `ClientSort` in each container: "Sort & filter" reads it.
#Preview("Without a connection") {
    let container = try! ModelContainer(
        for: Client.self, ClientSegment.self, ClientSort.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(Client(
        id: "1", externalId: "1", firstName: "Alice", lastName: "Martinez",
        primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78", segment: "VIC"
    ))
    container.mainContext.insert(
        ClientSegment(code: "VIC", backgroundColorHex: "#14545F", textColorHex: "#ffffff", rank: 0)
    )
    container.mainContext.insert(Client(
        id: "2", externalId: "2", firstName: "Raphaël", lastName: "Van den Berg",
        primaryPhone: "+33 6 98 76 54 32"
    ))
    return NavigationStack {
        ClientsView()
    }
    .modelContainer(container)
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
}

#Preview("No clients yet") {
    let container = try! ModelContainer(
        for: Client.self, ClientSegment.self, ClientSort.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return NavigationStack {
        ClientsView()
    }
    .modelContainer(container)
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
}

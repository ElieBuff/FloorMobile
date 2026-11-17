//
//  PagedSearchList.swift
//  FloorMobile
//

import SwiftUI

/// What the server finds for a query and its filters, a page at a time: the
/// first once the typing pauses — at once without a text —, the next as the
/// end of the list comes into
/// view, a spinner while one is on its way, and, when the first comes back
/// empty, the system's "No Results" — or, for a search without text, the
/// parent's own empty state (`emptyLabel`) — in the app's list look
/// (`.insetGroupedList()`).
///
/// A next page that fails raises "Search failed" over the list: the pages
/// above it stay, and "Try again" fetches it again. A first page that fails
/// is the parent's (`onFirstPageFailure`): nothing of the search is on
/// screen, and a closed alert would leave it empty — the parent puts
/// something in the list's place: what the device holds (the client list
/// without filters), or `LoadFailureView`, whose "Try again" builds the list
/// afresh (with filters). The shortest query the server accepts is the
/// parent's rule too — it builds the list only for a query worth sending.
///
/// Native inside — `.task(id:)`, `List`, `ContentUnavailableView.search`.
/// One caller since "All Brand" left with its screen (12/11), the client
/// list, and still a type of its own: its rules (`SearchPages`) are tested on
/// their own, and the Search tab's plan gives it its second caller back.
///
/// ```swift
/// PagedSearchList(query: text) {
///     try await services.clients.searchClients($0, after: $1, using: session.api)
/// } onFirstPageFailure: { query, error in
///     failedSearch = (query, error)   // something else takes the list's place
/// } row: { client in
///     ClientRow(client: client, segment: segments.first { $0.code == client.segment })
/// }
/// ```
///
/// A search that depends on more than its text — a sort, filters — passes it
/// too, `PagedSearchList(query: text, restartingOn: options) { … }`: a change
/// of it starts the search over from its first page, as a new text does.
///
/// The view is built once and lives across searches. A new search is declared
/// by `.onChange`, which starts the pages over (`SearchPages.start`). One
/// `.task(id:)` on the request the pages ask for: SwiftUI starts the fetch
/// when it changes — a new search's first page, the next page, a retry —
/// cancels the one under way, cancels it too when the list goes away, and
/// starts it again every time the list comes back on screen (a tab switch, a
/// push), which `beginFetch` turns down for a page already there.
struct PagedSearchList<Item: Identifiable, Row: View>: View {
    /// What the server is asked for, as it is sent: the parent trims it.
    let query: String
    /// What else the search depends on — its sort, its filters. `nil` for a
    /// search on its text alone.
    let restartingOn: AnyHashable?
    /// What an empty first page shows for a search without text — a sort or
    /// filters alone, where the system's "No Results" would ask to check the
    /// spelling of a text no one typed. `nil` keeps "No Results".
    let emptyLabel: (title: String, systemImage: String)?
    /// One page of matches from a cursor (`nil` for the first page), and
    /// where the next one starts — `nil` once there is none. On the main
    /// actor, like a `Button`'s action: it is the parent's code, reading the
    /// parent's environment; the service it calls leaves the main actor on
    /// its own.
    let fetch: @MainActor (_ query: String, _ cursor: String?) async throws -> ([Item], String?)
    /// Told when the first page of a search fails, with its query and why —
    /// never when a fetch is cancelled because the search changed or the
    /// list left the screen.
    let onFirstPageFailure: (_ query: String, _ error: any Error) -> Void
    let row: (Item) -> Row

    @State private var pages: SearchPages<Item>
    /// The alert of a next page that failed; a new search closes it.
    @State private var alert: FloorAlert?

    /// How long the typing must pause before the first page of a text is
    /// asked for.
    /// Computed: a generic type cannot store a static property.
    private static var debounce: Duration { .milliseconds(300) }

    // Written out: a private `@State` makes the memberwise init private too.
    init(
        query: String,
        restartingOn: AnyHashable? = nil,
        emptyLabel: (title: String, systemImage: String)? = nil,
        fetch: @escaping @MainActor (_ query: String, _ cursor: String?) async throws -> ([Item], String?),
        onFirstPageFailure: @escaping (_ query: String, _ error: any Error) -> Void,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.query = query
        self.restartingOn = restartingOn
        self.emptyLabel = emptyLabel
        self.fetch = fetch
        self.onFirstPageFailure = onFirstPageFailure
        self.row = row
        _pages = State(initialValue: SearchPages(search: Self.search(query: query, restartingOn: restartingOn)))
    }

    /// The search as a whole: its query and what it restarts on. A change of
    /// it is a new search. Static, so the init reads it before `pages` is set.
    private static func search(query: String, restartingOn: AnyHashable?) -> AnyHashable {
        AnyHashable([AnyHashable(query), restartingOn])
    }

    var body: some View {
        List {
            ForEach(pages.items) { item in
                row(item)
                    .insetGroupedRow()
                    .onAppearNearEnd(of: pages.items, item: item) {
                        pages.requestNextPage()
                    }
            }
            if pages.status == .loading, !pages.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .insetGroupedList()
        .overlay { placeholder }
        .floorAlert($alert)
        // A new search: the pages start over, which changes the request the
        // task below runs on, and an alert about the last one goes.
        .onChange(of: Self.search(query: query, restartingOn: restartingOn)) { _, search in
            pages.start(search)
            alert = nil
        }
        .task(id: pages.request) {
            await load()
        }
    }

    /// What stands in for the list while it has nothing to show: a spinner
    /// until the first page lands, an empty state if it lands empty — and
    /// nothing after a failed first page, which is the parent's to show.
    @ViewBuilder
    private var placeholder: some View {
        if pages.items.isEmpty {
            switch pages.status {
            case .loading: ProgressView()
            case .loaded: emptyResults
            case .failed: EmptyView()
            }
        }
    }

    /// An empty first page: the system's "No Results" for a text, the
    /// parent's own words for a search without one.
    @ViewBuilder
    private var emptyResults: some View {
        if query.isEmpty, let emptyLabel {
            ContentUnavailableView(emptyLabel.title, systemImage: emptyLabel.systemImage)
        } else {
            ContentUnavailableView.search(text: query)
        }
    }

    // MARK: - Loading

    /// Fetches the page asked for, unless it is already on screen
    /// (`SearchPages.beginFetch`), and lands it under the others. The first
    /// page of a text waits for the typing to pause: a keystroke meanwhile is
    /// a new search, whose new request cancels the wait — so that page is
    /// never sent. Without a text nothing is being typed — a sort, filters,
    /// the tab opening, the device's list — and it goes at once.
    ///
    /// Whatever comes back for a request no longer asked for — the search
    /// changed, or the answer came after a cancellation it did not heed — is
    /// dropped: no page, no alert, nothing told to the parent. A late failure
    /// of an earlier sort would otherwise send the client list to the
    /// device's.
    private func load() async {
        guard pages.beginFetch() else { return }
        let request = pages.request
        do {
            if request.isFirstPage, !query.isEmpty {
                try await Task.sleep(for: Self.debounce)
            }
            let (page, next) = try await fetch(query, request.cursor)
            pages.land(page, next: next, for: request)
        } catch {
            // Cancelled: the search changed, or the list left the screen and
            // asks again once it is back. Not a failure either way.
            guard !Task.isCancelled, request == pages.request else { return }
            pages.fail(request)
            if request.isFirstPage {
                onFirstPageFailure(query, error)
            } else {
                alert = nextPageAlert(for: request, error: error)
            }
        }
    }

    /// "Search failed" with the error's message, for a page under those on
    /// screen: "Try again" fetches it again, the pages above it kept — and does
    /// nothing once the search has changed (`SearchPages.retry(_:)`); "Close"
    /// leaves the list as it is.
    private func nextPageAlert(for request: SearchPages<Item>.Request, error: any Error) -> FloorAlert {
        FloorAlert(
            kind: .error,
            title: String(localized: "Search failed"),
            message: error.localizedDescription,
            primary: AlertAction(label: String(localized: "Try again")) { pages.retry(request) },
            secondary: AlertAction(label: String(localized: "Close"), emphasis: .quiet)
        )
    }
}

// MARK: - Previews

/// A made-up result, to page through without a server.
nonisolated private struct PreviewResult: Identifiable {
    let id: Int
}

// A slow server with three pages of twenty: both spinners show, the one in
// the middle before the first page, the one at the bottom before the next.
#Preview("Pages") {
    PagedSearchList(query: "mar") { _, cursor in
        try await Task.sleep(for: .seconds(1))
        let start = cursor.flatMap { Int($0) } ?? 0
        let end = start + 20
        return ((start..<end).map { PreviewResult(id: $0) }, end < 60 ? String(end) : nil)
    } onFirstPageFailure: { _, _ in } row: { (result: PreviewResult) in
        Text(verbatim: "Result \(result.id + 1)")
    }
    .ambientBackground()
}

// The second page fails: scrolled to the end, the alert rises over the first,
// which stays.
#Preview("Next page fails") {
    PagedSearchList(query: "mar") { _, cursor in
        guard cursor == nil else { throw URLError(.notConnectedToInternet) }
        return ((0..<20).map { PreviewResult(id: $0) }, "20")
    } onFirstPageFailure: { _, _ in } row: { (result: PreviewResult) in
        Text(verbatim: "Result \(result.id + 1)")
    }
    .ambientBackground()
}

#Preview("No results") {
    PagedSearchList(query: "zzz") { _, _ in
        ([], nil)
    } onFirstPageFailure: { _, _ in } row: { (result: PreviewResult) in
        Text(verbatim: "Result \(result.id + 1)")
    }
    .ambientBackground()
}

// A sort or filters alone, without text: the parent's empty state, not "No Results".
#Preview("Empty without a text") {
    PagedSearchList(
        query: "", emptyLabel: (title: "Nothing matches", systemImage: "line.3.horizontal.decrease")
    ) { _, _ in ([], nil) } onFirstPageFailure: { _, _ in } row: { (result: PreviewResult) in
        Text(verbatim: "Result \(result.id + 1)")
    }
    .ambientBackground()
}

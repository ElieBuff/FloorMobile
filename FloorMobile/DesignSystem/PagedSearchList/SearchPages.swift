//
//  SearchPages.swift
//  FloorMobile
//

/// The pages of a server search, as `PagedSearchList` shows them: what is on
/// screen, the page asked for, and where that page stands.
///
/// A value type rather than `@State` scattered in the view, for the reason
/// `CalendarExpansion` is one: the rules are delicate, and none of them can be
/// checked by scrolling a list by hand — `SearchPagesTests` checks them
/// instead:
/// - a new search starts from nothing, and the same search again changes
///   nothing;
/// - an answer — a page, a failure, a "Try again" — counts only for the
///   request still asked for: one of a search or a page left behind, coming
///   late, changes nothing;
/// - a page lands once, and the next is asked for once, never after the last;
/// - a client the server repeats on the next page is shown once.
nonisolated struct SearchPages<Item: Identifiable> {
    /// What is on screen, in the server's order.
    private(set) var items: [Item] = []
    /// The page asked for. `PagedSearchList` fetches it each time it changes.
    private(set) var request: Request
    /// Where the page asked for stands.
    private(set) var status: Status = .loading
    /// Where the next page starts — `nil` before the first lands, and once
    /// there is none.
    private var nextCursor: String?

    /// The pages of `search`, nothing on screen yet: its first page is asked
    /// for.
    init(search: AnyHashable) {
        request = Request(search: search)
    }

    /// Where the page asked for stands.
    enum Status {
        /// On its way — or about to be.
        case loading
        /// On screen.
        case loaded
        /// Failed: nothing more until a retry, or until the list comes back on
        /// screen.
        case failed
    }

    /// A page asked for. A change of any of its fields fetches a page.
    struct Request: Equatable {
        /// The search the page belongs to — its query and whatever else it
        /// depends on, a sort or filters.
        var search: AnyHashable
        /// The page: `nil` for the first.
        var cursor: String? = nil
        /// Bumped by `retry(_:)`: the request changes, so the page is fetched
        /// again.
        var retries = 0

        /// Whether nothing of the search is on screen before this page.
        var isFirstPage: Bool { cursor == nil }
    }

    /// Starts `search` over from nothing and asks for its first page. Nothing
    /// for the search already on screen.
    mutating func start(_ search: AnyHashable) {
        guard search != request.search else { return }
        items = []
        nextCursor = nil
        request = Request(search: search)
        status = .loading
    }

    /// Whether the page asked for is to fetch — not once it is on screen: back
    /// on screen, the list asks again for the page it shows. A page that
    /// failed is fetched again, and is loading again.
    mutating func beginFetch() -> Bool {
        guard status != .loaded else { return false }
        status = .loading
        return true
    }

    /// Puts `page`, fetched for `request`, under what is on screen, and keeps
    /// where the next page starts. A client already on screen is left out:
    /// between two pages, a refresh of the server's name dictionary can repeat
    /// a few (`client-fuzzy-match.service.ts`).
    mutating func land(_ page: [Item], next: String?, for request: Request) {
        guard request == self.request else { return }
        let shown = Set(items.map(\.id))
        items += page.filter { !shown.contains($0.id) }
        nextCursor = next
        status = .loaded
    }

    /// Notes that `request`'s page failed.
    mutating func fail(_ request: Request) {
        guard request == self.request else { return }
        status = .failed
    }

    /// Asks for the page after the last one — once: nothing if there is none
    /// left, or if it is already asked for.
    mutating func requestNextPage() {
        guard let nextCursor, request.cursor != nextCursor else { return }
        request.cursor = nextCursor
        status = .loading
    }

    /// Asks again for the page that failed. Nothing once it is no longer the
    /// page asked for, or no longer failed — a "Try again" left on screen
    /// after the list fetched it again on its own.
    mutating func retry(_ request: Request) {
        guard request == self.request, status == .failed else { return }
        self.request.retries += 1
        status = .loading
    }
}

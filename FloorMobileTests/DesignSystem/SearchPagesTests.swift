//
//  SearchPagesTests.swift
//  FloorMobileTests
//

import Testing
@testable import FloorMobile

@Suite("Search pages")
struct SearchPagesTests {

    /// A made-up result: an id is all the pages look at.
    nonisolated private struct Match: Identifiable {
        let id: Int
    }

    private typealias Request = SearchPages<Match>.Request

    private static func matches(_ ids: ClosedRange<Int>) -> [Match] {
        ids.map { Match(id: $0) }
    }

    /// The pages of a search for "mar", nothing on screen yet.
    private static func pages(search: String = "mar") -> SearchPages<Match> {
        SearchPages(search: search)
    }

    // MARK: - Pages

    @Test("A new search asks for its first page, and is loading")
    func asksForTheFirstPage() {
        let pages = Self.pages()

        #expect(pages.request.isFirstPage)
        #expect(pages.needsFetch(pages.request))
        #expect(pages.loaded == nil)
        #expect(pages.isLoading)
    }

    @Test("The next page is asked for once, from where it starts, and is not a first page")
    func nextPageAskedForOnce() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)

        pages.requestNextPage()
        // Another row near the end appears: the page is already asked for.
        pages.requestNextPage()

        #expect(pages.request == Request(search: "mar", cursor: "page-2"))
        #expect(!pages.request.isFirstPage)
        #expect(pages.needsFetch(pages.request))
        #expect(pages.isLoading)
    }

    @Test("Nothing is asked for after the last page")
    func nothingAfterTheLastPage() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()
        // Page 2 is the last: no cursor after it.
        pages.land(Self.matches(4...6), next: nil, for: pages.request)
        let last = pages.request

        pages.requestNextPage()

        #expect(pages.request == last)
        #expect(!pages.needsFetch(pages.request))
        #expect(!pages.isLoading)
    }

    @Test("A page lands once, though asked for again after it landed")
    func pageLandsOnce() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()
        pages.land(Self.matches(4...6), next: "page-3", for: pages.request)

        // Back on screen, the list asks again for the page it shows…
        #expect(!pages.needsFetch(pages.request))
        // …and a "Try again" left on screen comes after that page landed.
        pages.retry(pages.request)
        #expect(!pages.needsFetch(pages.request))
        #expect(pages.items.map(\.id) == [1, 2, 3, 4, 5, 6])
    }

    @Test("A client the server repeats on the next page is shown once")
    func repeatedClientShownOnce() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()

        // A refresh of the server's dictionary between the two pages: client 3 comes again.
        pages.land(Self.matches(3...5), next: nil, for: pages.request)

        #expect(pages.items.map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test("A first page that comes back empty is told from one not back yet")
    func emptyFirstPageLands() {
        var pages = Self.pages()
        let first = pages.request

        pages.land([], next: nil, for: first)

        #expect(pages.items.isEmpty)
        #expect(pages.loaded == first)
        #expect(!pages.isLoading)
    }

    // MARK: - A new search

    @Test("A new search starts over from nothing and asks for its first page")
    func newSearchStartsOver() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()

        pages.start("mart")

        #expect(pages.items.isEmpty)
        #expect(pages.loaded == nil)
        #expect(pages.request == Request(search: "mart"))
        #expect(pages.needsFetch(pages.request))
        #expect(pages.isLoading)
        // No cursor of the last search carries over.
        pages.requestNextPage()
        #expect(pages.request.isFirstPage)
    }

    @Test("The same search again changes nothing, and a loaded list stays loaded")
    func sameSearchChangesNothing() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        let request = pages.request

        pages.start("mar")

        #expect(pages.request == request)
        #expect(pages.items.map(\.id) == [1, 2, 3])
        #expect(!pages.isLoading)
    }

    @Test("A page of a search left behind, coming back late, does not land")
    func latePageOfAnOldSearchIsDropped() {
        var pages = Self.pages()
        let old = pages.request

        pages.start("mart")
        pages.land(Self.matches(1...3), next: "page-2", for: old)

        #expect(pages.items.isEmpty)
        #expect(pages.loaded == nil)
        #expect(pages.isLoading)
    }

    @Test("Another search's first page is to fetch, though this one's first page landed")
    func otherSearchFirstPageNeedsFetch() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: nil, for: pages.request)

        // The same cursor, nil: only the search tells the two apart.
        #expect(!pages.needsFetch(Request(search: "mar")))
        #expect(pages.needsFetch(Request(search: "mart")))
    }

    // MARK: - Failures and retries

    @Test("A failure stops the loading; a retry asks again for exactly that page")
    func retryAsksForTheFailedPage() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()
        // Page 2 fails: nothing lands.
        let failed = pages.request
        pages.fail(failed)
        #expect(!pages.isLoading)

        pages.retry(failed)

        // A new request, so the task runs again — on the same page.
        #expect(pages.request != failed)
        #expect(pages.request.cursor == failed.cursor)
        #expect(pages.needsFetch(pages.request))
        #expect(pages.isLoading)
        #expect(pages.items.map(\.id) == [1, 2, 3])
    }

    @Test("A failed page fetched again as the list comes back on screen is loading again")
    func failedPageFetchedAgainIsLoading() {
        var pages = Self.pages()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()
        let failed = pages.request
        pages.fail(failed)

        // Back on screen, the task runs again on the same request.
        pages.fetching(failed)

        #expect(pages.request == failed)
        #expect(pages.isLoading)
    }

    @Test("Fetching a request left behind changes neither the failure nor the loading")
    func staleFetchingChangesNothing() {
        var pages = Self.pages()
        let old = pages.request
        pages.start("mart")
        pages.fail(pages.request)

        pages.fetching(old)

        #expect(!pages.isLoading)
    }

    @Test("A late failure of a request left behind changes neither the failure nor the loading")
    func lateFailureIsDropped() {
        var pages = Self.pages()
        let old = pages.request

        pages.start("mart")
        pages.fail(old)

        #expect(pages.failed == nil)
        #expect(pages.isLoading)
    }

    @Test("A retry of a search or a page left behind changes nothing")
    func staleRetryChangesNothing() {
        var pages = Self.pages()
        let oldSearch = pages.request
        pages.start("mart")
        let current = pages.request

        pages.retry(oldSearch)
        #expect(pages.request == current)

        // A page further on is asked for since the failure.
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        let firstPage = pages.request
        pages.requestNextPage()
        let nextPage = pages.request
        pages.retry(firstPage)
        #expect(pages.request == nextPage)
    }
}

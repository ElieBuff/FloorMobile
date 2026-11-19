//
//  ClientsViewTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// The Clients tab's rules, without the view: what the server is sent of the
/// text typed in the search field, when the device's clients stand in after
/// the server failed their first page, and what the subtitle says of the
/// server's totals.
@Suite("Clients search and fallback")
@MainActor
struct ClientsViewTests {

    // MARK: - Search text

    @Test("A text shorter than three characters, spaces aside, is not sent")
    func shortTextIsNotSent() {
        #expect(ClientsView.searchMinimumLength == 3)
        #expect(ClientsView.searchText(typed: "") == "")
        #expect(ClientsView.searchText(typed: "ra") == "")
        // Spaces do not count toward the three.
        #expect(ClientsView.searchText(typed: "  ra  ") == "")
    }

    @Test("From three characters on, the text is sent without the spaces around it")
    func longEnoughTextIsSent() {
        #expect(ClientsView.searchText(typed: "ram") == "ram")
        #expect(ClientsView.searchText(typed: " Diego Ramos \n") == "Diego Ramos")
    }

    // MARK: - Recent clients

    private static let recents = [ClientItem(id: "c1", firstName: "Alice")]

    @Test("The active field shows the recent clients until three characters are typed")
    func activeFieldShowsRecents() {
        #expect(ClientsView.showsRecents(isSearching: true, typed: "", recents: Self.recents))
        #expect(ClientsView.showsRecents(isSearching: true, typed: "ra", recents: Self.recents))
        // Spaces do not count toward the three.
        #expect(ClientsView.showsRecents(isSearching: true, typed: " ab ", recents: Self.recents))
    }

    @Test("From three characters on, the search takes the recent clients' place")
    func searchTakesOver() {
        #expect(!ClientsView.showsRecents(isSearching: true, typed: "ram", recents: Self.recents))
    }

    @Test("The field at rest, or no recent client to show, leaves the list")
    func listStays() {
        #expect(!ClientsView.showsRecents(isSearching: false, typed: "", recents: Self.recents))
        #expect(!ClientsView.showsRecents(isSearching: true, typed: "", recents: nil))
        #expect(!ClientsView.showsRecents(isSearching: true, typed: "", recents: []))
    }

    // MARK: - Fallback

    @Test("Without a connection, a text or a filter, the device stands in")
    func networkWithoutFilters() {
        #expect(ClientsView.showsDevice(
            after: AppError.network(underlying: nil), text: "", options: ClientSearchOptions()
        ))
        // A sort alone: the device lists by name, under the notice.
        #expect(ClientsView.showsDevice(
            after: AppError.network(underlying: nil), text: "", options: ClientSearchOptions(sortBy: "lastPurchase")
        ))
    }

    @Test("With filters, which the device cannot apply, the error shows")
    func networkWithFilters() {
        #expect(!ClientsView.showsDevice(
            after: AppError.network(underlying: nil), text: "", options: ClientSearchOptions(filters: [.value(ref: "a")])
        ))
    }

    @Test("With a text, which the device does not search, the error shows")
    func networkWithText() {
        #expect(!ClientsView.showsDevice(
            after: AppError.network(underlying: nil), text: "ramos", options: ClientSearchOptions()
        ))
    }

    @Test("A server that answers with an error shows it, never the device")
    func serverError() {
        #expect(!ClientsView.showsDevice(
            after: AppError.server(statusCode: 503), text: "", options: ClientSearchOptions()
        ))
    }

    // MARK: - Subtitle

    @Test("Without filters, the subtitle says the associate's total")
    func subtitleSaysTheBook() {
        #expect(ClientsView.subtitle(bookTotal: 536, filteredTotal: nil, isFiltered: false) == "536 in your book")
    }

    @Test("Until the server has answered, or for an empty book, the subtitle says nothing", arguments: [nil, 0] as [Int?])
    func subtitleWaitsForTheServer(bookTotal: Int?) {
        #expect(ClientsView.subtitle(bookTotal: bookTotal, filteredTotal: nil, isFiltered: false).isEmpty)
        #expect(ClientsView.subtitle(bookTotal: bookTotal, filteredTotal: 12, isFiltered: true).isEmpty)
    }

    @Test("With filters, the subtitle says how many they keep, of how many — even none", arguments: [12, 1, 0])
    func subtitleSaysTheFilters(filteredTotal: Int) {
        let subtitle = ClientsView.subtitle(bookTotal: 536, filteredTotal: filteredTotal, isFiltered: true)
        #expect(subtitle == "\(filteredTotal) of 536 clients")
    }

    @Test("With filters not counted yet, the subtitle says nothing rather than the book alone")
    func subtitleWaitsForTheFilters() {
        #expect(ClientsView.subtitle(bookTotal: 536, filteredTotal: nil, isFiltered: true).isEmpty)
    }
}

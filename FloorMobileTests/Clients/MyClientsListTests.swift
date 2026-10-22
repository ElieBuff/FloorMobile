//
//  MyClientsListTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// Where "My Clients" takes its list from — the rule, without the view.
@Suite("My Clients source")
@MainActor
struct MyClientsListTests {

    @Test("A short text with nothing picked stays on the device")
    func shortTextStaysOnDevice() {
        #expect(!MyClientsList.usesServer(text: "al", options: ClientSearchOptions()))
        #expect(!MyClientsList.usesServer(text: "", options: ClientSearchOptions()))
    }

    @Test("A sort or a filter picked asks the server, whatever the text")
    func pickAsksTheServer() {
        #expect(MyClientsList.usesServer(text: "al", options: ClientSearchOptions(filterRefs: ["a"])))
        #expect(MyClientsList.usesServer(text: "", options: ClientSearchOptions(sortBy: "lastPurchase")))
    }

    @Test("A text long enough asks the server")
    func longTextAsksTheServer() {
        #expect(MyClientsList.usesServer(text: "ali", options: ClientSearchOptions()))
    }
}

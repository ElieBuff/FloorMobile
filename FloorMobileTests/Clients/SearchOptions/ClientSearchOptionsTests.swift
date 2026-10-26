//
//  ClientSearchOptionsTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client search options")
struct ClientSearchOptionsTests {

    @Test("Nothing picked is the server's default; any one pick is not")
    func isDefault() {
        #expect(ClientSearchOptions().isDefault)
        #expect(!ClientSearchOptions(sortBy: "name").isDefault)
        #expect(!ClientSearchOptions(direction: .desc).isDefault)
        #expect(!ClientSearchOptions(filters: [ClientFilterChoice(ref: "a")]).isDefault)
    }
}

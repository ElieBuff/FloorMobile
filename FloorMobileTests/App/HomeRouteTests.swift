//
//  HomeRouteTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("HomeRoute")
struct HomeRouteTests {

    private let day = Date(timeIntervalSince1970: 1_788_377_164)

    @Test("Routes are equal when they carry the same values, so the stack can diff them")
    func equality() {
        #expect(HomeRoute.agenda(date: day) == HomeRoute.agenda(date: day))
        #expect(HomeRoute.agenda(date: day) != HomeRoute.agenda(date: day.addingTimeInterval(1)))
    }

    @Test("A route round-trips through Codable, keeping its date — the basis for state restoration and deep links")
    func codableRoundTrip() throws {
        let route = HomeRoute.agenda(date: day)
        let data = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(HomeRoute.self, from: data)
        #expect(decoded == route)
    }

    @Test("A whole path round-trips through Codable in order")
    func pathRoundTrip() throws {
        let path: [HomeRoute] = [.agenda(date: day), .agenda(date: day.addingTimeInterval(86_400))]
        let data = try JSONEncoder().encode(path)
        let decoded = try JSONDecoder().decode([HomeRoute].self, from: data)
        #expect(decoded == path)
    }
}

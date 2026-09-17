//
//  RouterTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Router")
@MainActor
struct RouterTests {

    private let day = Date(timeIntervalSince1970: 1_788_377_164)

    @Test("Starts at the root unless given a path")
    func initialPath() {
        #expect(Router<HomeRoute>().path.isEmpty)
        let seeded = Router<HomeRoute>(path: [.agenda(date: day)])
        #expect(seeded.path == [.agenda(date: day)])
    }

    @Test("Push appends to the top of the stack")
    func push() {
        let router = Router<HomeRoute>()
        router.push(.agenda(date: day))
        router.push(.agenda(date: day.addingTimeInterval(86_400)))
        #expect(router.path.count == 2)
        #expect(router.path.last == .agenda(date: day.addingTimeInterval(86_400)))
    }

    @Test("Pop removes only the top screen")
    func pop() {
        let router = Router<HomeRoute>(path: [.agenda(date: day), .agenda(date: day.addingTimeInterval(86_400))])
        router.pop()
        #expect(router.path == [.agenda(date: day)])
    }

    @Test("Pop at the root is a no-op, not a crash")
    func popAtRoot() {
        let router = Router<HomeRoute>()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test("Pop to root clears the whole stack")
    func popToRoot() {
        let router = Router<HomeRoute>(path: [.agenda(date: day), .agenda(date: day.addingTimeInterval(86_400))])
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}

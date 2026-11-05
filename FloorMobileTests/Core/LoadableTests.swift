//
//  LoadableTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// What a screen reads off a value it asked for: the value, the error, or
/// that it is still on its way — never two at once.
@Suite("Loadable")
struct LoadableTests {

    @Test("On its way: no value, no error")
    func loading() {
        let loadable = Loadable<Int>.loading

        #expect(loadable.isLoading)
        #expect(loadable.value == nil)
        #expect(loadable.error == nil)
    }

    @Test("Loaded: the value, no error")
    func loaded() {
        let loadable = Loadable<Int>.loaded(664)

        #expect(!loadable.isLoading)
        #expect(loadable.value == 664)
        #expect(loadable.error == nil)
    }

    @Test("Failed: the error, no value")
    func failed() {
        let loadable = Loadable<Int>.failed(AppError.server(statusCode: 503))

        #expect(!loadable.isLoading)
        #expect(loadable.value == nil)
        guard case .server(statusCode: 503)? = loadable.error as? AppError else {
            Issue.record("Expected AppError.server(503), got \(String(describing: loadable.error))")
            return
        }
    }
}

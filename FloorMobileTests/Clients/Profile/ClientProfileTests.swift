//
//  ClientProfileTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// A profile's three parts arrive at their own pace: each starts on its way,
/// and one arriving leaves the others where they stand.
@Suite("Client profile")
struct ClientProfileTests {

    @Test("A new profile has its three parts on their way")
    func startsLoading() {
        let profile = ClientProfile(clientID: "c1")

        #expect(profile.clientID == "c1")
        #expect(profile.details.isLoading)
        #expect(profile.summary.isLoading)
        #expect(profile.timeline.isLoading)
    }

    @Test("A part that arrives, or fails, leaves the two others as they were")
    func partsAreIndependent() {
        var profile = ClientProfile(clientID: "c1")
        let summary = ClientSummary(
            title: "A loyal client", brief: "Brief.", prose: "Prose.", nextStep: "Call her.", mood: .positive
        )

        profile.summary = .loaded(summary)
        profile.timeline = .failed(AppError.server(statusCode: 502))

        #expect(profile.details.isLoading)
        #expect(profile.summary.value == summary)
        #expect(profile.timeline.error != nil)
    }
}

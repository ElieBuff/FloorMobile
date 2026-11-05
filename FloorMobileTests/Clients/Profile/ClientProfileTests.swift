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

    // MARK: - Failures

    @Test("No part failed: no error for the page's notice")
    func noFailureNoError() {
        var profile = ClientProfile(clientID: "c1")
        profile.summary = .loaded(ClientSummary(title: "", brief: "", prose: "", nextStep: "", mood: nil))

        #expect(profile.firstError == nil)
    }

    @Test("The notice's error is the details', else the summary's, else the timeline's")
    func firstErrorInOrder() {
        var profile = ClientProfile(clientID: "c1")
        profile.timeline = .failed(AppError.server(statusCode: 404))
        profile.summary = .failed(AppError.server(statusCode: 502))

        guard case .server(statusCode: 502)? = profile.firstError as? AppError else {
            Issue.record("Expected the summary's AppError.server(502), got \(String(describing: profile.firstError))")
            return
        }

        profile.details = .failed(AppError.network(underlying: nil))

        guard case .network? = profile.firstError as? AppError else {
            Issue.record("Expected the details' AppError.network, got \(String(describing: profile.firstError))")
            return
        }
    }

    @Test("Trying again puts back on their way only the parts that failed")
    func retryFailedOnly() {
        let summary = ClientSummary(title: "", brief: "Brief.", prose: "", nextStep: "", mood: nil)
        var profile = ClientProfile(clientID: "c1")
        profile.summary = .loaded(summary)
        profile.details = .failed(AppError.network(underlying: nil))
        profile.timeline = .failed(AppError.network(underlying: nil))

        profile.retryFailed()

        #expect(profile.details.isLoading)
        #expect(profile.timeline.isLoading)
        #expect(profile.summary.value == summary)
        #expect(profile.firstError == nil)
    }
}

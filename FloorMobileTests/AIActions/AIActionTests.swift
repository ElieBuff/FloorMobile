//
//  AIActionTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AIAction model")
struct AIActionTests {

    /// 2026-09-05T00:00:00Z — between the fixture's displayAt and expiresAt.
    private var midWindow: Date { Date(timeIntervalSince1970: 1_788_566_400) }

    private func makeAction(
        statusRaw: String = "PENDING",
        displayAt: Date? = nil,
        expiresAt: Date? = nil
    ) -> AIAction {
        AIAction(
            id: "01TEST",
            agentKey: "contact-radar",
            type: "ANNIVERSARY_TRAVEL_WISHES",
            title: "t",
            reason: "r",
            statusRaw: statusRaw,
            createdAt: Date(timeIntervalSince1970: 1_788_377_164),
            displayAt: displayAt,
            expiresAt: expiresAt
        )
    }

    @Test("Mapping from the wire format flattens people")
    func mappingFromDTO() throws {
        let dto = try #require(
            try APIClient.makeDecoder()
                .decode([AIActionDTO].self, from: Fixture.data("ai_actions_page1"))
                .first
        )

        let action = AIAction(dto: dto)

        #expect(action.id == dto.id)
        #expect(action.statusRaw == "PENDING")
        #expect(action.status == .pending)
        #expect(action.clientFirstName == "Elie")
        #expect(action.clientLastName == "Buff")
        #expect(action.salesAssociateFirstName == "Elie")
        #expect(action.salesAssociateLastName == "Buff")
        #expect(action.clientDisplayName == "Elie Buff")
    }

    @Test("An unknown server status yields no typed status")
    func unknownStatusIsNil() {
        #expect(makeAction(statusRaw: "SOME_FUTURE_STATUS").status == nil)
        #expect(makeAction(statusRaw: "REJECTED").status == .rejected)
    }

    @Test("Client display name handles partial and missing names")
    func clientDisplayNameFallbacks() {
        let action = makeAction()
        action.clientFirstName = nil
        action.clientLastName = "Buff"
        #expect(action.clientDisplayName == "Buff")

        action.clientLastName = nil
        #expect(action.clientDisplayName == nil)

        action.clientFirstName = "  "
        #expect(action.clientDisplayName == nil)
    }

    @Test("Expiry is evaluated against the injected date")
    func expiryUsesInjectedDate() {
        let action = makeAction(expiresAt: midWindow)
        #expect(!action.isExpired(at: midWindow.addingTimeInterval(-1)))
        #expect(action.isExpired(at: midWindow))
        #expect(!makeAction(expiresAt: nil).isExpired(at: midWindow))
    }

    @Test("Displayable = pending, window open, not expired")
    func displayableRules() {
        let window = makeAction(
            displayAt: midWindow.addingTimeInterval(-3600),
            expiresAt: midWindow.addingTimeInterval(3600)
        )
        #expect(window.isDisplayable(at: midWindow))
        // Before the display window opens.
        #expect(!window.isDisplayable(at: midWindow.addingTimeInterval(-7200)))
        // After expiry.
        #expect(!window.isDisplayable(at: midWindow.addingTimeInterval(7200)))
        // No window bounds at all: displayable as long as it is pending.
        #expect(makeAction().isDisplayable(at: midWindow))
        // Wrong status.
        #expect(!makeAction(statusRaw: "REJECTED").isDisplayable(at: midWindow))
    }
}

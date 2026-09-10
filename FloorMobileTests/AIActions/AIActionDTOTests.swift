//
//  AIActionDTOTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AIAction wire format")
struct AIActionDTOTests {

    @Test("Decodes a real API response, nested people included")
    func decodesRealResponse() throws {
        let actions = try APIClient.makeDecoder()
            .decode([AIActionDTO].self, from: Fixture.data("ai_actions_page1"))

        let action = try #require(actions.first)
        #expect(actions.count == 1)
        #expect(action.id == "01M1HSBTH7TPQV8EZQFKN1ES25")
        #expect(action.agentKey == "contact-radar")
        #expect(action.type == "ANNIVERSARY_TRAVEL_WISHES")
        #expect(action.title == "Anniversaire de mariage & départ au Portugal")
        #expect(action.status == "PENDING")
        // Fractional-seconds ISO 8601, as configured in APIClient.
        #expect(action.createdAt.timeIntervalSince1970 == 1_788_377_164.327)
        #expect(action.displayAt?.timeIntervalSince1970 == 1_788_300_000)
        #expect(action.expiresAt?.timeIntervalSince1970 == 1_788_904_800)
        #expect(action.eventDate == nil)
        #expect(action.rejectedAt == nil)
        #expect(action.rejectReason == nil)
        #expect(action.confidence == nil)
        #expect(action.client?.firstName == "Elie")
        #expect(action.client?.lastName == "Buff")
        #expect(action.salesAssociate?.firstName == "Elie")
        #expect(action.salesAssociate?.lastName == "Buff")
    }

    @Test("Unknown enum-like values and missing people do not fail decoding")
    func toleratesUnknownValuesAndMissingPeople() throws {
        // Server enums are open sets and people can be absent: the wire
        // format must swallow both without a decoding error.
        let json = """
        [
            {
                "id": "01TEST",
                "agentKey": "some-new-agent",
                "type": "A_TYPE_THIS_APP_VERSION_IGNORES",
                "title": "t",
                "reason": "r",
                "status": "SOME_FUTURE_STATUS",
                "createdAt": "2026-09-02T19:26:04.327Z",
                "displayAt": null,
                "eventDate": null,
                "expiresAt": null,
                "rejectedAt": null,
                "rejectReason": null,
                "confidence": 0.87,
                "client": null,
                "salesAssociate": null
            }
        ]
        """
        let actions = try APIClient.makeDecoder()
            .decode([AIActionDTO].self, from: Data(json.utf8))

        let action = try #require(actions.first)
        #expect(action.status == "SOME_FUTURE_STATUS")
        #expect(action.confidence == 0.87)
        #expect(action.client == nil)
        #expect(action.salesAssociate == nil)
    }
}

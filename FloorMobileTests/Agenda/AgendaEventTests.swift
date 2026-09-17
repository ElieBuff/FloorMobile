//
//  AgendaEventTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AgendaEvent wire format & mapping")
struct AgendaEventTests {

    @Test("Decodes a page and flattens people and store into the model")
    func mapsFromDTO() throws {
        let page = try APIClient.makeDecoder()
            .decode(CursorPage<EventDTO>.self, from: Fixture.data("event_agenda_page1"))

        #expect(page.hasMore)
        #expect(page.nextCursor == "cursor-2")

        let dto = try #require(page.items.first)
        let event = AgendaEvent(dto: dto)

        #expect(event.id == "01M2FQ54RZ39T1TDG4E8YJWCS0")
        #expect(event.statusRaw == "PLANNED")
        #expect(event.reasonRaw == "APPOINTMENT")
        #expect(event.meetingTypeRaw == "IN_PERSON")
        #expect(event.title == "Essayage collection automne")
        #expect(event.eventDescription == "RDV essayage")
        #expect(event.duration == 45)
        #expect(event.client?.id == "001cfde7-0c26-48ae-990c-68bbd710211b")
        #expect(event.client?.externalId == "seed-client-000289")
        #expect(event.client?.segment == "VIC")
        #expect(event.client?.metrics?.totalSpent12M == 0)
        #expect(event.client?.metrics?.totalSpentLifetime != nil)
        #expect(event.clientDisplayName == "Raphaël Van den Berg")
        #expect(event.store?.name == "My Custom Location")
        #expect(event.salesAssociate?.id == "01KTRSFERMNXK5FGSQW11M1478")
        // Meeting type + client segment drive the summary line.
        #expect(event.meetingSummary == "In Person • VIC")
        // End = start + 45 min.
        #expect(event.endDate.timeIntervalSince(event.startDate) == 45 * 60)
    }

    @Test("A null server reason decodes and maps to .other")
    func nullReasonMapsToOther() throws {
        let json = Data("""
        {
            "id": "event-no-reason",
            "status": "PLANNED",
            "reason": null,
            "title": "Sans motif",
            "startDate": "2026-09-20T10:00:00.000Z",
            "duration": 30,
            "createdAt": "2026-09-14T11:43:05.743Z",
            "updatedAt": "2026-09-14T11:43:05.743Z"
        }
        """.utf8)

        let dto = try APIClient.makeDecoder().decode(EventDTO.self, from: json)
        let event = AgendaEvent(dto: dto)

        #expect(event.reasonRaw == Reason.other.rawValue)
        #expect(event.reason == .other)
    }
}

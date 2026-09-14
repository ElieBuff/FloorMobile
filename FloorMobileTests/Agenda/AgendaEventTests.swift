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
        #expect(event.typeRaw == "APPOINTMENT")
        #expect(event.title == "Essayage collection automne")
        #expect(event.eventDescription == "RDV essayage")
        #expect(event.duration == 45)
        #expect(event.client?.id == "001cfde7-0c26-48ae-990c-68bbd710211b")
        #expect(event.clientDisplayName == "Raphaël Van den Berg")
        #expect(event.store?.name == "My Custom Location")
        #expect(event.salesAssociate?.id == "01KTRSFERMNXK5FGSQW11M1478")
        // End = start + 45 min.
        #expect(event.endDate.timeIntervalSince(event.startDate) == 45 * 60)
    }
}

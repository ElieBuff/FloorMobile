//
//  ClientTimelineWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// `client/{id}/timeline` as the local BFF served it for two seeded clients,
/// captured on 04/11/2026: one with transactions, tasks and appointments
/// (`client_timeline.json`), one with a conversation among its transactions
/// (`client_timeline_conversation.json`) — no seeded client has all four.
@Suite("Client timeline wire")
struct ClientTimelineWireTests {

    /// A captured timeline, decoded the way `APIClient` decodes it.
    private static func wire(_ fixture: String = "client_timeline") throws -> ClientTimelineWire.Response {
        try APIClient.makeDecoder().decode(ClientTimelineWire.Response.self, from: try Fixture.data(fixture))
    }

    @Test("Every line is kept, in the server's order")
    func everyLineInOrder() throws {
        let wire = try Self.wire()
        let timeline = ClientTimeline(wire: wire)

        #expect(timeline.upcoming.map(\.id) == wire.upcoming.map(\.id))
        #expect(timeline.past.map(\.id) == wire.past.map(\.id))
        #expect(timeline.upcoming.count == 8)
        #expect(timeline.past.count == 22)
    }

    @Test("A task line keeps its date, raw status, title and text")
    func taskLineMaps() throws {
        let line = try #require(ClientTimeline(wire: try Self.wire()).upcoming.first)

        #expect(line.id == "01M2MTG42H3T3HDNXWDD0NT5QX")
        #expect(line.kind == .task)
        #expect(line.date == Date(timeIntervalSince1970: 1_789_552_800))  // 2026-09-16T10:00:00Z
        #expect(line.status == "TO_DO")
        #expect(line.title == "Rappeler Mme Dupont")
        #expect(line.subtitle == [.text("Relance suite essayage")])
    }

    @Test("An appointment's reason and meeting type stay raw, beside its text")
    func appointmentPartsMap() throws {
        let line = try #require(
            ClientTimeline(wire: try Self.wire()).past.first { $0.id == "01M2FQ54RZ39T1TDG4E8YJWCS0" }
        )

        #expect(line.kind == .event)
        #expect(line.subtitle == [.reason("BACK_IN_STOCK"), .meetingType("IN_PERSON"), .text("RDV essayage")])
    }

    @Test("A transaction's item count and amount are read, its currency kept")
    func transactionPartsMap() throws {
        let line = try #require(
            ClientTimeline(wire: try Self.wire()).past.first { $0.id == "15760008-61b3-481e-aedb-b5a60f0e0e95" }
        )

        #expect(line.kind == .transaction)
        #expect(line.status == "PAID")
        #expect(line.title == "VESTE ACACIA · Selling Plans Ski Wax · T-SHIRT CESAR")
        #expect(line.subtitle == [.itemCount(4), .amount(Decimal(string: "237.9")!, currency: "USD")])
    }

    @Test("A conversation line is read with its associate and the start of its last message")
    func conversationLineMaps() throws {
        let line = try #require(ClientTimeline(wire: try Self.wire("client_timeline_conversation")).past[1])

        #expect(line.kind == .conversation)
        #expect(line.status == "ACTIVE")
        #expect(line.title == "Henry Clark")
        #expect(line.subtitle == [.text("Perfect, thank you")])
    }

    @Test("A transaction without a title or a status is kept")
    func bareTransactionKept() throws {
        // Every captured transaction names a product and has a status: both are cleared on the decoded wire.
        var wire = try Self.wire()
        let index = try #require(wire.past.firstIndex { $0.type == "transaction" })
        wire.past[index].title = nil
        wire.past[index].status = nil

        let line = ClientTimeline(wire: wire).past[index]

        #expect(line.kind == .transaction)
        #expect(line.title == nil)
        #expect(line.status == nil)
    }

    @Test("A line of a type this build does not know is left out, the others kept")
    func unknownLineSkipped() throws {
        // The server sends only known types: a line's type is changed on the decoded wire.
        var wire = try Self.wire()
        let skipped = wire.past[0].id
        wire.past[0].type = "visit"

        let timeline = ClientTimeline(wire: wire)

        #expect(timeline.past.count == 21)
        #expect(!timeline.past.contains { $0.id == skipped })
    }

    @Test("A part of a type this build does not know, or missing what its type needs, is left out")
    func unknownPartSkipped() throws {
        // The server sends only known parts, complete: two of them are changed on the decoded wire.
        var wire = try Self.wire()
        let index = try #require(wire.past.firstIndex { $0.id == "01M2FQ54RZ39T1TDG4E8YJWCS0" })
        wire.past[index].subtitle[0].type = "weather"
        wire.past[index].subtitle[1].meetingType = nil

        let line = ClientTimeline(wire: wire).past[index]

        #expect(line.subtitle == [.text("RDV essayage")])
    }
}

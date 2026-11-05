//
//  ClientTimelineItemTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// How a timeline line reads on screen — its subtitle and its status —, on
/// the lines the local BFF served for two seeded clients (captured on
/// 04/11/2026, see `ClientTimelineWireTests`).
@Suite("Client timeline item")
@MainActor
struct ClientTimelineItemTests {

    /// A captured timeline, decoded the way `APIClient` decodes it.
    private static func wire(_ fixture: String = "client_timeline") throws -> ClientTimelineWire.Response {
        try APIClient.makeDecoder().decode(ClientTimelineWire.Response.self, from: try Fixture.data(fixture))
    }

    /// The captured line `id`, converted.
    private static func line(_ id: String, in wire: ClientTimelineWire.Response) throws -> ClientTimelineItem {
        try #require(ClientTimeline(wire: wire).past.first { $0.id == id })
    }

    private static let appointmentID = "01M2FQ54RZ39T1TDG4E8YJWCS0"
    private static let transactionID = "15760008-61b3-481e-aedb-b5a60f0e0e95"

    // MARK: - Subtitle

    @Test("An appointment's reason and meeting type read as the agenda names them, before its text")
    func appointmentSubtitle() throws {
        let line = try Self.line(Self.appointmentID, in: try Self.wire())

        #expect(line.subtitleText == "Back in stock · In store · RDV essayage")
    }

    @Test("A purchase reads its item count, then its total in its currency")
    func purchaseSubtitle() throws {
        let line = try Self.line(Self.transactionID, in: try Self.wire())
        let total = Decimal(string: "237.9")!.formatted(.currency(code: "USD"))

        #expect(line.subtitleText == "4 items · \(total)")
    }

    @Test("One item is said in the singular")
    func singleItem() throws {
        // Every captured purchase holds several items: one count is set to 1 on the decoded wire.
        var wire = try Self.wire()
        let index = try #require(wire.past.firstIndex { $0.id == Self.transactionID })
        wire.past[index].subtitle[0].count = 1

        let line = try Self.line(Self.transactionID, in: wire)

        #expect(line.subtitleText.hasPrefix("1 item · "))
    }

    @Test("A total without a currency is still read, as a number")
    func totalWithoutCurrency() throws {
        // Every captured total has its currency: it is cleared on the decoded wire.
        var wire = try Self.wire()
        let index = try #require(wire.past.firstIndex { $0.id == Self.transactionID })
        wire.past[index].subtitle[1].currency = nil

        let line = try Self.line(Self.transactionID, in: wire)

        #expect(line.subtitleText == "4 items · \(Decimal(string: "237.9")!.formatted())")
    }

    // MARK: - Status

    @Test("Each kind's status reads in words")
    func statusLabels() throws {
        let timeline = ClientTimeline(wire: try Self.wire())
        let conversations = ClientTimeline(wire: try Self.wire("client_timeline_conversation"))

        #expect(try Self.line(Self.appointmentID, in: try Self.wire()).statusLabel == "Planned")
        #expect(try Self.line(Self.transactionID, in: try Self.wire()).statusLabel == "Paid")
        #expect(timeline.upcoming.first { $0.kind == .task }?.statusLabel == "To do")
        #expect(conversations.past.first { $0.kind == .conversation }?.statusLabel == "Active")
    }

    @Test("A status this build does not know shows nothing rather than a raw code")
    func unknownStatusHidden() throws {
        // The server sends only known statuses: two are changed on the decoded wire.
        var wire = try Self.wire()
        let transaction = try #require(wire.past.firstIndex { $0.id == Self.transactionID })
        let appointment = try #require(wire.past.firstIndex { $0.id == Self.appointmentID })
        wire.past[transaction].status = "ON_HOLD"
        wire.past[appointment].status = "RESCHEDULED"

        #expect(try Self.line(Self.transactionID, in: wire).statusLabel == nil)
        #expect(try Self.line(Self.appointmentID, in: wire).statusLabel == nil)
    }
}

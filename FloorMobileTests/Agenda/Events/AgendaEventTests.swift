//
//  AgendaEventTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AgendaEvent")
struct AgendaEventTests {

    /// A fixed calendar and a fixed day: the whole point of passing `now` in is
    /// that these tests read the same at 3am as at noon.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendar
    }()

    private static func moment(_ hour: Int, _ minute: Int = 0, day: Int = 7) throws -> Date {
        try #require(Self.calendar.date(
            from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)
        ))
    }

    private static func event(
        _ id: String,
        at start: Date,
        duration: Int = 30,
        status: String = "PLANNED"
    ) -> AgendaEvent {
        AgendaEvent(
            id: id, statusRaw: status, reasonRaw: "FOLLOW_UP",
            title: "Essayage", startDate: start, duration: duration,
            createdAt: start, updatedAt: start
        )
    }

    // MARK: - Wire format & mapping

    @Test("Decodes a page and flattens people and store into the model")
    func mapsFromWire() throws {
        let page = try APIClient.makeDecoder()
            .decode(CursorPage<EventWire.Response>.self, from: Fixture.data("event_agenda_page1"))

        #expect(page.hasMore)
        #expect(page.nextCursor == "cursor-2")

        let wire = try #require(page.items.first)
        let event = AgendaEvent(wire: wire)

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
        // Read off the type rather than copied: the label has been renamed
        // once already, and a literal here fails on the rename, not on a bug.
        #expect(event.meetingSummary == "\(MeetingType.inPerson.displayLabel) • VIC")
        // End = start + 45 min.
        #expect(event.endDate.timeIntervalSince(event.startDate) == 45 * 60)
    }

    /// Stored as absent, not as "OTHER": the stored value is what an edit
    /// sends back, and the server has no such reason.
    @Test("A null server reason is stored as absent, and reads as .other")
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

        let wire = try APIClient.makeDecoder().decode(EventWire.Response.self, from: json)
        let event = AgendaEvent(wire: wire)

        #expect(event.reasonRaw == nil)
        #expect(event.reason == .other)
    }

    // MARK: - Agenda day

    @Test("The agenda day is midnight of the start date's own day, late evening included")
    func agendaDayIsMidnightOfTheStartDay() throws {
        let calendar = Calendar.current
        let lateEvening = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 23, minute: 30))
        )
        let event = AgendaEvent(
            id: "late", statusRaw: "PLANNED", reasonRaw: "APPOINTMENT", title: "Tard",
            startDate: lateEvening, duration: 30, createdAt: .now, updatedAt: .now
        )

        #expect(event.agendaDay == calendar.startOfDay(for: lateEvening))
        // The 30 minutes past midnight must not push the event onto the 21st.
        #expect(calendar.component(.day, from: event.agendaDay) == 20)
    }

    // MARK: - Standing

    @Test("A cancelled appointment stays cancelled, whatever the hour")
    func cancelledIgnoresTheClock() throws {
        let past = Self.event("1", at: try Self.moment(9), status: "CANCELLED")
        let future = Self.event("2", at: try Self.moment(18), status: "CANCELLED")
        let now = try Self.moment(11, 20)

        #expect(past.standing(at: now) == .cancelled)
        #expect(future.standing(at: now) == .cancelled)
    }

    @Test("An appointment closed out early reads as done before its slot ends")
    func completedBeatsTheClock() throws {
        let event = Self.event("1", at: try Self.moment(14), duration: 60, status: "COMPLETED")
        #expect(event.standing(at: try Self.moment(14, 10)) == .done)
    }

    @Test("For anything the server still calls open, the clock decides", arguments: ["PLANNED", "CONFIRMED", "WHO_KNOWS"])
    func openStatusesAreJudgedOnTime(status: String) throws {
        let event = Self.event("1", at: try Self.moment(9, 30), duration: 30, status: status)

        #expect(event.standing(at: try Self.moment(9, 0)) == .upcoming)
        #expect(event.standing(at: try Self.moment(11, 0)) == .done)
    }

    @Test("The appointment you are sitting in is not greyed out")
    func inProgressStaysUpcoming() throws {
        let event = Self.event("1", at: try Self.moment(14), duration: 60)
        // Started half an hour ago, ends in half an hour.
        #expect(event.standing(at: try Self.moment(14, 30)) == .upcoming)
    }

    @Test("The boundary is the end instant itself")
    func pastBeginsAtTheEndInstant() throws {
        let event = Self.event("1", at: try Self.moment(14), duration: 60)
        let endsAt = try Self.moment(15)

        #expect(event.standing(at: endsAt.addingTimeInterval(-1)) == .upcoming)
        #expect(event.standing(at: endsAt) == .done)
        #expect(event.standing(at: endsAt.addingTimeInterval(1)) == .done)
    }

    // MARK: - Progress

    @Test("Progress runs from 0 at the start to 1 at the end, and stays inside")
    func progressIsClampedToTheSlot() throws {
        let event = Self.event("1", at: try Self.moment(14), duration: 60)

        #expect(event.progress(at: try Self.moment(13)) == 0)
        #expect(event.progress(at: try Self.moment(14)) == 0)
        #expect(event.progress(at: try Self.moment(14, 30)) == 0.5)
        #expect(event.progress(at: try Self.moment(15)) == 1)
        #expect(event.progress(at: try Self.moment(16)) == 1)
    }

    @Test("A zero-length appointment has no progress to report")
    func zeroLengthHasNoProgress() throws {
        let start = try Self.moment(14)
        #expect(Self.event("1", at: start, duration: 0).progress(at: start) == nil)
    }

    // MARK: - Next appointment

    @Test("The next appointment is the soonest one still ahead today")
    func nextIsTheSoonestAhead() throws {
        let events = [
            Self.event("late", at: try Self.moment(18)),
            Self.event("past", at: try Self.moment(9)),
            Self.event("soon", at: try Self.moment(14)),
        ]

        let next = AgendaEvent.next(in: events, at: try Self.moment(11, 20), calendar: Self.calendar)

        #expect(next?.id == "soon")
    }

    @Test("An appointment starting this very minute is still the next one")
    func startingNowCountsAsNext() throws {
        let event = Self.event("1", at: try Self.moment(14))
        let next = AgendaEvent.next(in: [event], at: try Self.moment(14), calendar: Self.calendar)
        #expect(next?.id == "1")
    }

    @Test("An appointment that has started is no longer the next one")
    func startedIsNotNext() throws {
        let event = Self.event("1", at: try Self.moment(14))
        let next = AgendaEvent.next(in: [event], at: try Self.moment(14, 1), calendar: Self.calendar)
        #expect(next == nil)
    }

    /// The query feeding this is wider than a day; tomorrow must not leak into
    /// today's card, nor today's into tomorrow's once midnight has passed.
    @Test("Only the day `now` falls in is considered")
    func otherDaysAreIgnored() throws {
        let tomorrow = Self.event("tomorrow", at: try Self.moment(9, day: 8))
        let today = Self.event("today", at: try Self.moment(23, 30, day: 7))

        #expect(
            AgendaEvent.next(in: [tomorrow], at: try Self.moment(20, day: 7), calendar: Self.calendar) == nil
        )
        #expect(
            AgendaEvent.next(in: [today, tomorrow], at: try Self.moment(0, 5, day: 8), calendar: Self.calendar)?.id
                == "tomorrow"
        )
    }
}

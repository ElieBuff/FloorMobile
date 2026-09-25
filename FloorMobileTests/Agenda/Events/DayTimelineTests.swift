//
//  DayTimelineTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("DayTimeline")
struct DayTimelineTests {

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

    private func items(_ events: [AgendaEvent], now: Date, day: Date) -> [DayTimeline.Item] {
        DayTimeline.items(events: events, now: now, day: day, calendar: Self.calendar)
    }

    private static func rule(of item: DayTimeline.Item) -> DayTimeline.NowRule? {
        guard case .event(_, _, let rule) = item else { return nil }
        return rule
    }

    /// Every rule the list carries — there is never more than one.
    private static func rules(of items: [DayTimeline.Item]) -> [DayTimeline.NowRule] {
        items.compactMap(rule(of:))
    }

    // MARK: - Standing

    @Test("A cancelled appointment stays cancelled, whatever the hour")
    func cancelledIgnoresTheClock() throws {
        let past = Self.event("1", at: try Self.moment(9), status: "CANCELLED")
        let future = Self.event("2", at: try Self.moment(18), status: "CANCELLED")
        let now = try Self.moment(11, 20)

        #expect(DayTimeline.standing(of: past, at: now) == .cancelled)
        #expect(DayTimeline.standing(of: future, at: now) == .cancelled)
    }

    @Test("An appointment closed out early reads as done before its slot ends")
    func completedBeatsTheClock() throws {
        let event = Self.event("1", at: try Self.moment(14), duration: 60, status: "COMPLETED")
        #expect(DayTimeline.standing(of: event, at: try Self.moment(14, 10)) == .done)
    }

    @Test("For anything the server still calls open, the clock decides", arguments: ["PLANNED", "CONFIRMED", "WHO_KNOWS"])
    func openStatusesAreJudgedOnTime(status: String) throws {
        let event = Self.event("1", at: try Self.moment(9, 30), duration: 30, status: status)

        #expect(DayTimeline.standing(of: event, at: try Self.moment(9, 0)) == .upcoming)
        #expect(DayTimeline.standing(of: event, at: try Self.moment(11, 0)) == .done)
    }

    @Test("The appointment you are sitting in is not greyed out")
    func inProgressStaysUpcoming() throws {
        let event = Self.event("1", at: try Self.moment(14), duration: 60)
        // Started half an hour ago, ends in half an hour.
        #expect(DayTimeline.standing(of: event, at: try Self.moment(14, 30)) == .upcoming)
    }

    @Test("The boundary is the end instant itself")
    func pastBeginsAtTheEndInstant() throws {
        let event = Self.event("1", at: try Self.moment(14), duration: 60)
        let endsAt = try Self.moment(15)

        #expect(DayTimeline.standing(of: event, at: endsAt.addingTimeInterval(-1)) == .upcoming)
        #expect(DayTimeline.standing(of: event, at: endsAt) == .done)
        #expect(DayTimeline.standing(of: event, at: endsAt.addingTimeInterval(1)) == .done)
    }

    // MARK: - Ordering and the rule between rows

    @Test("With nothing under way, the rule sits before the first appointment still to come")
    func ruleSplitsPastFromFuture() throws {
        let now = try Self.moment(11, 20)
        let day = try Self.moment(0)
        let events = [
            Self.event("09:30", at: try Self.moment(9, 30)),
            Self.event("10:30", at: try Self.moment(10, 30)),
            Self.event("14:00", at: try Self.moment(14), duration: 60),
            Self.event("16:00", at: try Self.moment(16)),
        ]

        let result = items(events, now: now, day: day)

        #expect(result.map(\.id) == ["09:30", "10:30", "now", "14:00", "16:00"])
        #expect(result[0] == .event(events[0], standing: .done, rule: nil))
        #expect(result[3] == .event(events[2], standing: .upcoming, rule: nil))
    }

    @Test("Once every appointment has run, the rule closes the list")
    func ruleGoesLast() throws {
        let events = [Self.event("a", at: try Self.moment(9)), Self.event("b", at: try Self.moment(10))]
        let result = items(events, now: try Self.moment(18), day: try Self.moment(0))

        #expect(result.map(\.id) == ["a", "b", "now"])
    }

    @Test("Before the first appointment, the rule opens the list")
    func ruleGoesFirst() throws {
        let events = [Self.event("a", at: try Self.moment(14)), Self.event("b", at: try Self.moment(16))]
        let result = items(events, now: try Self.moment(8), day: try Self.moment(0))

        #expect(result.map(\.id) == ["now", "a", "b"])
    }

    // MARK: - The rule on an appointment under way

    @Test("The rule crosses the appointment you are in, where you are in it")
    func ruleCrossesTheAppointmentUnderWay() throws {
        // Noon to one, five minutes in.
        let events = [Self.event("12:00", at: try Self.moment(12), duration: 60)]
        let now = try Self.moment(12, 5)

        let result = items(events, now: now, day: try Self.moment(0))

        // One rule, and it is not a row of its own.
        #expect(result.map(\.id) == ["12:00"])
        #expect(result[0] == .event(
            events[0],
            standing: .upcoming,
            rule: DayTimeline.NowRule(date: now, progress: 5.0 / 60.0)
        ))
    }

    @Test("An appointment under way keeps the past above it and the future below")
    func ruleOnlyOnTheAppointmentUnderWay() throws {
        let events = [
            Self.event("09:30", at: try Self.moment(9, 30)),
            Self.event("12:00", at: try Self.moment(12), duration: 60),
            Self.event("16:00", at: try Self.moment(16)),
        ]

        let result = items(events, now: try Self.moment(12, 30), day: try Self.moment(0))

        #expect(result.map(\.id) == ["09:30", "12:00", "16:00"])
        #expect(Self.rules(of: result).count == 1)
        #expect(Self.rule(of: result[1])?.progress == 0.5)
    }

    @Test("On the starting second, the rule is at the very top of the row")
    func ruleStartsAtTheTopOfTheRow() throws {
        let start = try Self.moment(14)
        let result = items([Self.event("a", at: start)], now: start, day: try Self.moment(0))

        #expect(result.map(\.id) == ["a"])
        #expect(Self.rule(of: result[0])?.progress == 0)
    }

    /// The end instant is the same boundary `standing(of:at:)` uses, so the row
    /// greys out and gives up the rule in the same breath.
    @Test("On the ending second, the row is done and the rule steps out of it")
    func ruleLeavesTheRowWhenItEnds() throws {
        let start = try Self.moment(14)
        let events = [Self.event("a", at: start, duration: 60)]
        let ends = try Self.moment(15)

        let justBefore = items(events, now: ends.addingTimeInterval(-1), day: try Self.moment(0))
        #expect(justBefore.map(\.id) == ["a"])
        #expect(Self.rule(of: justBefore[0]) != nil)

        let atTheEnd = items(events, now: ends, day: try Self.moment(0))
        #expect(atTheEnd.map(\.id) == ["a", "now"])
        #expect(Self.rules(of: atTheEnd).isEmpty)
    }

    /// A slot with no length has no inside to be in — so it gets no rule, and
    /// the standalone one takes over rather than nothing being drawn.
    @Test("A zero-length appointment carries no rule")
    func zeroLengthAppointmentCarriesNoRule() throws {
        let start = try Self.moment(14)
        let result = items([Self.event("a", at: start, duration: 0)], now: start, day: try Self.moment(0))

        #expect(Self.rules(of: result).isEmpty)
        #expect(result.map(\.id) == ["now", "a"])
    }

    @Test("When two appointments overlap, the earlier one carries the rule")
    func overlapGivesTheRuleToTheEarlierAppointment() throws {
        let events = [
            Self.event("09:00", at: try Self.moment(9), duration: 300),
            Self.event("11:00", at: try Self.moment(11), duration: 60),
        ]

        let result = items(events, now: try Self.moment(11, 30), day: try Self.moment(0))

        #expect(Self.rules(of: result).count == 1)
        #expect(Self.rule(of: result[0]) != nil)
    }

    @Test("Browsing another day draws no rule on an appointment either")
    func noRuleOnAnAppointmentOnAnotherDay() throws {
        // Same wall-clock hour as `now`, but tomorrow: an appointment under way
        // today must not put a rule on tomorrow's.
        let events = [Self.event("a", at: try Self.moment(12, day: 8), duration: 60)]
        let result = items(events, now: try Self.moment(12, 5), day: try Self.moment(0, day: 8))

        #expect(result.map(\.id) == ["a"])
        #expect(Self.rules(of: result).isEmpty)
    }

    @Test("Browsing another day draws no current-time rule")
    func noMarkerOnAnotherDay() throws {
        let events = [Self.event("a", at: try Self.moment(14, day: 8))]
        let result = items(events, now: try Self.moment(11, 20), day: try Self.moment(0, day: 8))

        #expect(result.map(\.id) == ["a"])
    }

    @Test("An empty day gets no rule either — the empty card stands alone")
    func noMarkerWithoutEvents() throws {
        let result = items([], now: try Self.moment(11, 20), day: try Self.moment(0))
        #expect(result.isEmpty)
    }

    @Test("Events come out in order however they went in")
    func sortsWhateverItIsHanded() throws {
        let events = [
            Self.event("16:00", at: try Self.moment(16)),
            Self.event("09:30", at: try Self.moment(9, 30)),
            Self.event("14:00", at: try Self.moment(14)),
        ]
        let result = items(events, now: try Self.moment(23), day: try Self.moment(0))

        #expect(result.map(\.id) == ["09:30", "14:00", "16:00", "now"])
    }

    // MARK: - Identity

    @Test("Two instances of the same stored row are the same item")
    func comparedByIdNotByObject() throws {
        let start = try Self.moment(14)
        let one = DayTimeline.Item.event(Self.event("42", at: start), standing: .upcoming, rule: nil)
        let other = DayTimeline.Item.event(Self.event("42", at: start), standing: .upcoming, rule: nil)

        #expect(one == other)
    }

    @Test("A row that changed state is a different item")
    func standingBreaksEquality() throws {
        let event = Self.event("42", at: try Self.moment(14))
        #expect(
            DayTimeline.Item.event(event, standing: .upcoming, rule: nil)
                != .event(event, standing: .done, rule: nil)
        )
    }

    /// The rule has to break equality, or the row would never redraw and the
    /// line would sit where it was when the screen appeared.
    @Test("A row whose rule moved is a different item")
    func aMovedRuleBreaksEquality() throws {
        let event = Self.event("42", at: try Self.moment(14), duration: 60)
        let at = try Self.moment(14, 5)
        let later = try Self.moment(14, 6)

        #expect(
            DayTimeline.Item.event(event, standing: .upcoming, rule: DayTimeline.NowRule(date: at, progress: 5.0 / 60))
                != .event(event, standing: .upcoming, rule: DayTimeline.NowRule(date: later, progress: 6.0 / 60))
        )
    }

    // MARK: - Next appointment

    @Test("The next appointment is the soonest one still ahead today")
    func nextAppointmentIsTheSoonestAhead() throws {
        let events = [
            Self.event("late", at: try Self.moment(18)),
            Self.event("past", at: try Self.moment(9)),
            Self.event("soon", at: try Self.moment(14)),
        ]

        let next = DayTimeline.nextAppointment(in: events, at: try Self.moment(11, 20), calendar: Self.calendar)

        #expect(next?.id == "soon")
    }

    @Test("An appointment starting this very minute is still the next one")
    func startingNowCountsAsNext() throws {
        let event = Self.event("1", at: try Self.moment(14))
        let next = DayTimeline.nextAppointment(in: [event], at: try Self.moment(14), calendar: Self.calendar)
        #expect(next?.id == "1")
    }

    @Test("An appointment that has started is no longer the next one")
    func startedIsNotNext() throws {
        let event = Self.event("1", at: try Self.moment(14))
        let next = DayTimeline.nextAppointment(in: [event], at: try Self.moment(14, 1), calendar: Self.calendar)
        #expect(next == nil)
    }

    /// The query feeding this is wider than a day; tomorrow must not leak into
    /// today's card, nor today's into tomorrow's once midnight has passed.
    @Test("Only the day `now` falls in is considered")
    func otherDaysAreIgnored() throws {
        let tomorrow = Self.event("tomorrow", at: try Self.moment(9, day: 8))
        let today = Self.event("today", at: try Self.moment(23, 30, day: 7))

        #expect(
            DayTimeline.nextAppointment(in: [tomorrow], at: try Self.moment(20, day: 7), calendar: Self.calendar) == nil
        )
        #expect(
            DayTimeline.nextAppointment(in: [today, tomorrow], at: try Self.moment(0, 5, day: 8), calendar: Self.calendar)?.id
                == "tomorrow"
        )
    }

    @Test("Two standalone rules are equal, so a quiet minute animates nothing")
    func standaloneRulesAreAlwaysEqual() {
        // The `.now` row holds no date on purpose: were it to carry one, the
        // list would compare unequal on every tick and the section would
        // animate a move that never happened. The rule *on* a row is the
        // opposite case — it does move, see `aMovedRuleBreaksEquality`.
        #expect(DayTimeline.Item.now == DayTimeline.Item.now)
    }
}

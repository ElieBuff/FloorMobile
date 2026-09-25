//
//  CollapsibleCalendar.swift
//  FloorMobile
//

import SwiftUI

/// The calendar card at the top of the agenda: one week, or the whole month when
/// you pull it down.
///
/// The two states are not two layouts. There is a single six-row month grid;
/// collapsed, the card is tall enough for one row and the grid is offset so that
/// the row holding the anchor day sits at the top. Expanding interpolates that
/// one offset and one height, which is why the gesture can track the finger
/// continuously instead of cutting between two designs — and why the selected
/// day never moves while the rest of the month grows around it.
///
/// The component knows nothing about the app's domain: it takes a selected day
/// and a list of days that hold something, and hands back a selection.
///
/// ```swift
/// CollapsibleCalendar(selection: $day, daysWithEvents: events.map(\.startDate))
/// ```
///
/// - Note: it carries its own drag gesture. Inside a `ScrollView` the two will
///   compete, so keep it pinned above the scrolling content rather than in it.
struct CollapsibleCalendar: View {
    @Binding var selection: Date

    private let grid: CalendarGrid
    /// Days that get a dot, normalised to midnight so lookups are exact.
    private let eventDays: Set<Date>

    /// The day whose week (or month) the card is showing. Separate from the
    /// selection on purpose: paging with the arrows or a swipe browses the
    /// calendar without changing which day the screen below is about.
    @State private var anchor: Date
    /// Week or month, plus wherever a finger in flight has taken it. All the
    /// arithmetic of the two states lives in the type, not here.
    @State private var expansion = CalendarExpansion()
    @State private var pageShift: CGFloat = 0
    @State private var dragAxis: Axis?
    @State private var pageWidth: CGFloat = 0
    @State private var isTurningPage = false
    /// Bumped on every committed page turn, so `sensoryFeedback` fires one tick
    /// per turn without coupling to `anchor` (which also moves on day selection).
    @State private var pageTurns = 0
    /// Bumped on every day tap, so selection gets its own haptic tick.
    @State private var daySelections = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fonts scale with Dynamic Type (the grid geometry stays fixed, so growth is
    // capped on the card below).
    @ScaledMetric(relativeTo: .caption2) private var weekdayFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .subheadline) private var titleFontSize: CGFloat = 13

    init(selection: Binding<Date>, daysWithEvents: [Date] = [], calendar: Calendar = .current) {
        _selection = selection
        _anchor = State(initialValue: selection.wrappedValue)
        self.grid = CalendarGrid(calendar: calendar)
        self.eventDays = Set(daysWithEvents.map { calendar.startOfDay(for: $0) })
    }

    var body: some View {
        VStack(spacing: CalendarMetrics.sectionSpacing) {
            header
            VStack(spacing: CalendarMetrics.rowSpacing) {
                weekdayRow
                pager
            }
            handle
        }
        .padding(.vertical, CalendarMetrics.cardPaddingVertical)
        .padding(.horizontal, CalendarMetrics.cardPaddingHorizontal)
        .cardStyle(shadow: .low)
        // The grid is 7×6 fixed cells, so cap Dynamic Type growth: the fonts
        // scale up to here, past which the numbers would overflow their pills.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .gesture(dragGesture)
        .onChange(of: selection) { _, newValue in
            // A page turn already drives the anchor (see `goToToday`); don't let
            // this handler jump it mid-slide.
            guard !isTurningPage, !grid.isSameDay(newValue, anchor) else { return }
            withAnimation(expandAnimation()) { anchor = newValue }
        }
        // A soft tick when the month/week toggles, a page turns, or a day is
        // picked — the feedback native calendars give, and this one was missing.
        .sensoryFeedback(.selection, trigger: expansion.isExpanded)
        .sensoryFeedback(.selection, trigger: pageTurns)
        .sensoryFeedback(.selection, trigger: daySelections)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            arrow(
                direction: -1,
                systemImage: "chevron.left",
                label: expansion.isExpanded ? String(localized: "Previous month") : String(localized: "Previous week")
            )

            titleStrip

            arrow(
                direction: 1,
                systemImage: "chevron.right",
                label: expansion.isExpanded ? String(localized: "Next month") : String(localized: "Next week")
            )
        }
        .padding(.horizontal, CalendarMetrics.headerInset)
        .frame(height: CalendarMetrics.headerHeight)
    }

    /// A jump-to-today control, shown only once the displayed week (or month) has
    /// drifted off the current one — the affordance every calendar offers to get
    /// straight back.
    private var todayButton: some View {
        Button(action: goToToday) {
            Text(String(localized: "Today"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(.OnSurface.textPrimary))
                // The word is a few points tall on an 8pt row; the target is
                // the strip the handle owns — see `handleHitHeight`.
                .frame(minWidth: CalendarMetrics.hitTarget, minHeight: CalendarMetrics.handleHitHeight)
                .padding(.top, -(CalendarMetrics.sectionSpacing - CalendarMetrics.rowSpacing))
                .padding(.bottom, -CalendarMetrics.cardPaddingVertical)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Go to today"))
    }

    private func arrow(direction: Int, systemImage: String, label: String) -> some View {
        Button {
            page(by: direction)
        } label: {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(.OnSurface.textSecondary))
                // A 16pt glyph in a 19pt header, with a 44pt target: the frame
                // grows, the negative padding hands the difference back, and
                // the header stays exactly as drawn. The overflow lands on the
                // card's padding and the title strip, neither of which answers
                // a tap.
                .frame(width: CalendarMetrics.hitTarget, height: CalendarMetrics.hitTarget)
                .padding(.horizontal, -(CalendarMetrics.hitTarget - CalendarMetrics.arrowSize) / 2)
                .padding(.vertical, -(CalendarMetrics.hitTarget - CalendarMetrics.headerHeight) / 2)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The month names ride with the grid instead of waiting for it.
    ///
    /// Left in the header, the title could only change once the slide was over,
    /// so every page turn ended on a word popping — the content said one thing
    /// while the label still said another. Three titles on the same offset as
    /// the pages fix that, and the one leaving dissolves as it goes, the way
    /// FSCalendar's header does.
    private var titleStrip: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            HStack(spacing: 0) {
                title(for: neighbour(-1), slot: -1, width: width)
                title(for: anchor, slot: 0, width: width)
                title(for: neighbour(1), slot: 1, width: width)
            }
            .offset(x: -width + pageFraction * width)
        }
        .frame(height: CalendarMetrics.headerHeight)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(grid.monthTitle(for: anchor))
        .accessibilityAddTraits(.isHeader)
    }

    private func title(for date: Date, slot: Int, width: CGFloat) -> some View {
        let offCentre = min(abs(CGFloat(slot) + pageFraction), 1)
        return Text(grid.monthTitle(for: date))
            .font(.system(size: titleFontSize, weight: .medium))
            .foregroundStyle(Color(.OnSurface.textPrimary))
            .lineLimit(1)
            .frame(width: width)
            .opacity(1 - (1 - CalendarMetrics.titleDissolve) * offCentre)
    }

    /// How far the pager has travelled, as a share of one page: 0 at rest, -1
    /// when the next page has fully arrived.
    private var pageFraction: CGFloat {
        pageWidth > 0 ? pageShift / pageWidth : 0
    }


    // MARK: - Grid

    private var weekdayRow: some View {
        HStack(spacing: CalendarMetrics.columnSpacing) {
            ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: weekdayFontSize, weight: .medium))
                    .foregroundStyle(Color(.OnSurface.textTertiary))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: CalendarMetrics.weekdayRowHeight)
        .accessibilityHidden(true)
    }

    private var pager: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                monthPage(for: neighbour(-1), width: proxy.size.width)
                monthPage(for: anchor, width: proxy.size.width)
                monthPage(for: neighbour(1), width: proxy.size.width)
            }
            .offset(x: -proxy.size.width + pageShift)
        }
        .calendarReveal(progress: expansion.progress)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
    }

    /// One page of the pager: always the full six-row month around `date`,
    /// pushed up so that `date`'s own row is the one left showing when the card
    /// is collapsed.
    private func monthPage(for date: Date, width: CGFloat) -> some View {
        let days = grid.monthPage(containing: date)
        let anchorRow = grid.rowIndex(of: date, in: days) ?? 0

        return VStack(spacing: CalendarMetrics.rowSpacing) {
            ForEach(0 ..< CalendarGrid.rowCount, id: \.self) { row in
                // Every row is drawn at full strength: the window uncovers them,
                // it does not fade them in. Cross-fading five rows at once turns
                // the middle of the gesture into a wall of ghosts, where a plain
                // reveal reads as one piece of paper sliding.
                weekRow(
                    days: Array(days[(row * CalendarGrid.daysPerWeek) ..< ((row + 1) * CalendarGrid.daysPerWeek)]),
                    month: date
                )
                .calendarRowSettle(distance: row - anchorRow, progress: expansion.settledProgress)
                // The window clips what it draws, but the rows it hides stay laid
                // out (pushed up by the offset below) and SwiftUI keeps them
                // tappable — right under the header and the handle. Left alone, a
                // tap on an arrow or the handle lands on a day cell that isn't on
                // screen, selecting a hidden day and jumping the calendar to its
                // week. So a row outside the revealed window takes no touches.
                .allowsHitTesting(isRowRevealed(row, anchorRow: anchorRow))
            }
        }
        .frame(width: width)
        .offset(y: -CGFloat(anchorRow) * (CalendarMetrics.rowHeight + CalendarMetrics.rowSpacing) * (1 - expansion.settledProgress))
    }

    /// Whether `row` overlaps the revealed rows window, read in the same geometry
    /// the reveal uses: the grid is pushed up by the collapsed anchor offset, and
    /// the window is one row tall collapsed, the whole month tall expanded. Rows
    /// falling outside it are hidden by the clip — and must not be tappable.
    private func isRowRevealed(_ row: Int, anchorRow: Int) -> Bool {
        let step = CalendarMetrics.rowHeight + CalendarMetrics.rowSpacing
        let y = CGFloat(row) * step - CGFloat(anchorRow) * step * (1 - expansion.settledProgress)
        let windowHeight = CalendarMetrics.collapsedRowsHeight
            + CalendarMetrics.expandDistance * expansion.settledProgress
        return y + CalendarMetrics.rowHeight > 0 && y < windowHeight
    }

    private func weekRow(days: [Date], month: Date) -> some View {
        HStack(spacing: CalendarMetrics.columnSpacing) {
            ForEach(days, id: \.self) { day in
                CalendarDayCell(
                    date: day,
                    dayNumber: grid.dayNumber(of: day),
                    isSelected: grid.isSameDay(day, selection),
                    isToday: grid.isSameDay(day, .now),
                    isInDisplayedMonth: grid.isDate(day, inSameMonthAs: month),
                    hasEvents: eventDays.contains(grid.calendar.startOfDay(for: day))
                ) {
                    select(day)
                }
            }
        }
        .frame(height: CalendarMetrics.rowHeight)
    }

    // MARK: - Handle

    private var handle: some View {
        Capsule()
            .fill(Color(.OnSurface.borderSubtle))
            .frame(width: CalendarMetrics.handleWidth, height: CalendarMetrics.handleThickness)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: CalendarMetrics.handleHeight, alignment: .bottom)
            // The strip the handle owns, not a 44pt square: the rows above
            // and the card's edge below are spoken for — see `handleHitHeight`.
            .frame(height: CalendarMetrics.handleHitHeight)
            .padding(.top, -(CalendarMetrics.sectionSpacing - CalendarMetrics.rowSpacing))
            .padding(.bottom, -CalendarMetrics.cardPaddingVertical)
            .contentShape(.rect)
            .onTapGesture { setExpanded(!expansion.isExpanded) }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(expansion.isExpanded ? String(localized: "Show the week") : String(localized: "Show the month"))
            // Today lives on the handle row, at the trailing edge, out of the
            // header so it never crowds the arrows. Overlaid rather than laid
            // out: showing or hiding it moves neither the centred handle nor the
            // grid above. It only appears once the shown period has drifted off
            // the current one.
            .overlay(alignment: .trailing) {
                todayButton
                    .padding(.trailing, CalendarMetrics.headerInset)
                    .opacity(isShowingToday ? 0 : 1)
                    .allowsHitTesting(!isShowingToday)
                    .animation(expandAnimation(), value: isShowingToday)
            }
    }

    // MARK: - State

    /// The page one step away, in whichever unit the current state pages by.
    /// Month pages are anchored on the 1st so that repeated paging can't drift
    /// (the 31st plus a month is the 28th, and never finds its way back).
    private func neighbour(_ direction: Int) -> Date {
        expansion.isExpanded
            ? grid.date(byAddingMonths: direction, to: grid.startOfMonth(containing: anchor))
            : grid.date(byAddingWeeks: direction, to: anchor)
    }

    private func select(_ day: Date) {
        let wasSelected = grid.isSameDay(day, selection)
        daySelections += 1
        selection = day

        // Picking a day out of the month grid is a way of going there, so the
        // card gets out of the way — but not when the tap only confirms the day
        // already selected, which would close the month for nothing.
        if expansion.isExpanded && !wasSelected {
            withAnimation(expandAnimation()) {
                anchor = day
                expansion.settle(toExpanded: false)
            }
        } else {
            anchor = day
        }
    }

    /// Whether the displayed week (or month) already contains today.
    private var isShowingToday: Bool {
        isSamePeriod(anchor, as: .now)
    }

    /// Brings both the anchor and the selection back to today: a slide when today
    /// is one page away (the usual case after paging once), a straight jump when
    /// it is further, since sliding across many months would be worse than a cut.
    private func goToToday() {
        let today = Date()
        daySelections += 1

        // Navigate first, set the selection last: assigning `selection` fires
        // `onChange`, and doing it before the page turn would make that handler
        // jump the anchor mid-slide (the pill flickering off and back).
        if isSamePeriod(neighbour(1), as: today) {
            page(by: 1)
        } else if isSamePeriod(neighbour(-1), as: today) {
            page(by: -1)
        } else if !isSamePeriod(anchor, as: today) {
            withAnimation(expandAnimation()) { anchor = today }
        }
        selection = today
    }

    /// Whether two dates fall in the same shown period — month when expanded,
    /// week when collapsed.
    private func isSamePeriod(_ a: Date, as b: Date) -> Bool {
        expansion.isExpanded
            ? grid.isDate(a, inSameMonthAs: b)
            : grid.isSameDay(grid.startOfWeek(containing: a), grid.startOfWeek(containing: b))
    }

    /// The expand/collapse spring, taking the finger's velocity so a released
    /// gesture continues its movement instead of starting a new one.
    /// `initialVelocity` is in units of the animated value per second, hence the
    /// division by the travel still to cover in `setExpanded`.
    private static func settle(velocity: Double = 0) -> Animation {
        .interpolatingSpring(duration: 0.35, bounce: 0.12, initialVelocity: velocity)
    }

    /// Under Reduce Motion the expand spring collapses to a short ease.
    private func expandAnimation(velocity: Double = 0) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : Self.settle(velocity: velocity)
    }

    /// The horizontal page turn. Deliberately a plain, velocity-free ease: the
    /// pager swaps its three-page window the instant the slide lands, so a
    /// spring's tail (or a mis-signed initial velocity) makes that swap fire at
    /// the wrong moment — which snapped the page back and read as a loop between
    /// two weeks. Reduce Motion shortens it.
    private var pageAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.32)
    }

    /// Settles the card into one of its two states, carrying the finger's speed
    /// into the spring so a released gesture continues its movement instead of
    /// starting a new one. The handover itself is `CalendarExpansion`'s job.
    private func setExpanded(_ expanded: Bool, velocity: CGFloat = 0) {
        let handover = expansion.handoverVelocity(toExpanded: expanded, velocity: velocity)
        withAnimation(expandAnimation(velocity: handover)) {
            expansion.settle(toExpanded: expanded)
        }
    }

    /// Slides the neighbouring page in, then adopts it. Committing only once the
    /// slide has finished keeps the three-page window centred: the pager always
    /// renders previous / current / next, so the anchor may only move when the
    /// offset is about to be reset.
    private func page(by direction: Int) {
        guard pageWidth > 0 else {
            anchor = neighbour(direction)
            return
        }
        // One turn at a time. A second slide started while the first turn's
        // completion is still pending leaves that completion to land mid-slide
        // and snap everything back to centre — the same tap would sometimes
        // slide and sometimes just swap the numbers.
        guard !isTurningPage else { return }
        isTurningPage = true
        pageTurns += 1
        let destination = neighbour(direction)
        withAnimation(pageAnimation, completionCriteria: .logicallyComplete) {
            pageShift = -CGFloat(direction) * pageWidth
        } completion: {
            // Explicitly unanimated. The swap only works because it is invisible:
            // the new anchor moves the three-page window one slot forward at the
            // same instant the offset returns to centre, which lands on exactly
            // the pixels already on screen. Let the completion inherit the
            // animation it was called from and the offset slides back instead —
            // the page turns, then walks straight back where it came from.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                anchor = destination
                pageShift = 0
                isTurningPage = false
            }
        }
    }

    // MARK: - Gesture

    /// One gesture for both axes, locked to the first direction the finger takes.
    /// Sharing a single recogniser is what keeps a diagonal drag from expanding
    /// the card and turning the page at the same time.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragAxis == nil {
                    dragAxis = abs(value.translation.width) > abs(value.translation.height)
                        ? .horizontal
                        : .vertical
                }
                switch dragAxis {
                case .horizontal:
                    pageShift = value.translation.width
                case .vertical:
                    expansion.drag(by: value.translation.height)
                case nil:
                    break
                }
            }
            .onEnded { value in
                switch dragAxis {
                case .horizontal:
                    // The projected landing point, not the current one: a short
                    // flick should turn the page like a long slow drag does.
                    let projected = value.predictedEndTranslation.width
                    let threshold = max(pageWidth / 3, 1)
                    if projected <= -threshold {
                        page(by: 1)
                    } else if projected >= threshold {
                        page(by: -1)
                    } else {
                        withAnimation(pageAnimation) { pageShift = 0 }
                    }
                case .vertical:
                    // The gesture's speed converted into progress per second;
                    // where that lands the card is `CalendarExpansion`'s call.
                    let velocity = value.velocity.height / CalendarMetrics.expandDistance
                    setExpanded(expansion.opensOnRelease(velocity: velocity), velocity: velocity)
                case nil:
                    break
                }
                dragAxis = nil
            }
    }
}

// MARK: - Previews

#Preview("Week / month") {
    @Previewable @State var selection = Date()

    let calendar = Calendar.current
    let eventDays = [0, 1, 3, 6, 9, 14, 20].compactMap {
        calendar.date(byAdding: .day, value: $0, to: Date())
    }

    return VStack {
        CollapsibleCalendar(selection: $selection, daysWithEvents: eventDays)
        Text(selection, format: .dateTime.weekday(.wide).day().month(.wide))
            .font(.footnote)
            .foregroundStyle(Color(.OnCanvas.textSecondary))
            .padding(.top, 24)
        Spacer()
    }
    .padding(16)
    .ambientBackground()
}

//
//  CalendarDayCell.swift
//  FloorMobile
//

import SwiftUI

/// One day in the calendar grid: the number, its selection pill, and the dot
/// that says the day holds something.
///
/// Selection and "today" are drawn differently on purpose — a filled pill for
/// the day you picked, a ring for the day it actually is. They coincide on the
/// first render and part company as soon as you page away, which is exactly when
/// the distinction starts to matter.
struct CalendarDayCell: View {
    let date: Date
    let dayNumber: Int
    let isSelected: Bool
    let isToday: Bool
    /// False for the leading and trailing days a month page borrows from its
    /// neighbours; they stay visible but recede.
    let isInDisplayedMonth: Bool
    let hasEvents: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var numberFontSize: CGFloat = 13

    var body: some View {
        Button(action: action) {
            VStack(spacing: CalendarMetrics.dotSpacing) {
                Text(dayNumber, format: .number.grouping(.never))
                    .font(.system(size: numberFontSize, weight: .medium))
                    .foregroundStyle(numberColor)
                    .frame(width: CalendarMetrics.pillSize, height: CalendarMetrics.pillSize)
                    .background(pill)

                Circle()
                    .fill(Color(.OnSurface.textTertiary))
                    .frame(width: CalendarMetrics.dotSize, height: CalendarMetrics.dotSize)
                    .opacity(hasEvents ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            // The row plus the gap under it, given back with the negative
            // padding so the grid keeps its 40pt rows: the finger gets 46pt,
            // the eye sees nothing move.
            .frame(height: CalendarMetrics.dayCellHitHeight, alignment: .top)
            .padding(.bottom, -CalendarMetrics.rowSpacing)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(hasEvents ? String(localized: "Has events") : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var pill: some View {
        if isSelected {
            Circle().fill(Color(.Base.ink))
        } else if isToday {
            Circle().strokeBorder(Color(.OnSurface.textTertiary), lineWidth: 1)
        }
    }

    private var numberColor: Color {
        if isSelected {
            Color(.Base.paper)
        } else if isInDisplayedMonth {
            Color(.OnSurface.textPrimary)
        } else {
            Color(.OnSurface.textTertiary)
        }
    }
}

// MARK: - Previews

#Preview("States") {
    let day = Date()
    return HStack(spacing: CalendarMetrics.columnSpacing) {
        CalendarDayCell(date: day, dayNumber: 7, isSelected: true, isToday: true, isInDisplayedMonth: true, hasEvents: true) {}
        CalendarDayCell(date: day, dayNumber: 8, isSelected: false, isToday: true, isInDisplayedMonth: true, hasEvents: false) {}
        CalendarDayCell(date: day, dayNumber: 9, isSelected: false, isToday: false, isInDisplayedMonth: true, hasEvents: true) {}
        CalendarDayCell(date: day, dayNumber: 10, isSelected: false, isToday: false, isInDisplayedMonth: false, hasEvents: false) {}
    }
    .padding()
    .cardStyle()
    .padding(40)
    .background(Color(.Base.canvas))
}

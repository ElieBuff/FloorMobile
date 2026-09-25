//
//  EventRow.swift
//  FloorMobile
//

import SwiftUI

/// One appointment in the day's rail: the hour in the margin, then a card with
/// the client, what the meeting is, and how long it runs.
///
/// The row does no time arithmetic. It is handed a `Standing` and paints it —
/// which keeps its previews trivial and, more importantly, makes it impossible
/// for two rows on screen to disagree about what time it is. `DayTimeline`
/// decides; this draws.
struct EventRow: View {
    let event: AgendaEvent
    let standing: DayTimeline.Standing
    /// Where the current-time rule crosses this row, or `nil` — which is every
    /// row but the appointment under way. `DayTimeline` decides; this draws.
    var rule: DayTimeline.NowRule?
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Text(event.startDate, format: .dateTime.hour().minute())
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(.OnSurface.textTertiary))
                    .frame(width: 40, alignment: .leading)
                    .padding(.top, 14)

                card
            }
            .overlay(alignment: .top) { nowRule }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// The current-time rule across this row, at the fraction of the
    /// appointment that has elapsed.
    ///
    /// An overlay rather than a line of its own: the appointment you are in is
    /// neither over nor still to come, so a rule above or below it would put it
    /// on the wrong side of now. The same `NowMarker` the gaps use, so one
    /// drawing means one thing wherever it appears.
    ///
    /// `GeometryReader` reads the row's height without having any say in it —
    /// an overlay is sized by what it covers, not the other way round.
    @ViewBuilder
    private var nowRule: some View {
        if let rule {
            GeometryReader { proxy in
                NowMarker(date: rule.date)
                    // Collapsed to nothing so the offset below lands the rule's
                    // *line* — not the top of its label, which sits half a
                    // label higher. Its parts are centred on this zero height
                    // and overflow into the gap between rows rather than being
                    // clipped, so at 0 % the line is exactly on the row's edge.
                    .frame(height: 0)
                    .offset(y: proxy.size.height * rule.progress)
            }
        }
    }

    private var card: some View {
        // No colour on the leading edge any more: the reason is on the mark, and
        // saying it twice was saying it once too often.
        inner
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var inner: some View {
        HStack(spacing: 12) {
            mark

            VStack(alignment: .leading, spacing: 2) {
                Text(event.clientDisplayName ?? event.title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(standing.isDimmed ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textPrimary))
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(standing.isDimmed ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textSecondary))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(trailingLabel)
                .font(.caption2)
                .foregroundStyle(Color(.OnSurface.textTertiary))
                .fixedSize()
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
    }

    /// The same `ReasonIcon` a task row leads with, so a day reads as one list
    /// rather than two. It also fills the line an avatar could not: `client` is
    /// optional, and an appointment without one had nothing but an empty disc to
    /// show.
    ///
    /// 0.28 when the day has left it behind — the figure the leading edge used
    /// to carry, moved onto the object that took its place.
    private var mark: some View {
        ReasonIcon(reason: event.reason)
            .opacity(standing.isDimmed ? 0.28 : 1)
    }

    private var surface: Color {
        standing.isDimmed ? Color(.OnCanvas.surfaceMuted) : Color(.OnCanvas.surface)
    }

    /// What the meeting is: its type and the client's tier when the API sent
    /// them, and the event's own title otherwise.
    private var subtitle: String? {
        event.meetingSummary ?? (event.clientDisplayName == nil ? nil : event.title)
    }

    /// Duration while the appointment still lies ahead; afterwards, what became
    /// of it — which is why `Standing` has three cases and not two.
    private var trailingLabel: String {
        switch standing {
        case .cancelled: String(localized: "Cancelled")
        case .done: String(localized: "Done")
        case .upcoming: durationLabel
        }
    }

    private var durationLabel: String {
        Duration.minutes(event.duration).hoursAndMinutes
    }
}

// MARK: - Previews

private func previewEvent(
    id: String,
    status: String,
    reason: String,
    /// `nil` for an appointment nobody is named on — the case the mark exists
    /// for.
    name: String?,
    title: String,
    hour: Int,
    duration: Int
) -> AgendaEvent {
    AgendaEvent(
        id: id, statusRaw: status, reasonRaw: reason, meetingTypeRaw: "IN_PERSON",
        title: title,
        startDate: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now,
        duration: duration, createdAt: .now, updatedAt: .now,
        client: name.map {
            ClientSummary(
                firstName: String($0.split(separator: " ").first ?? ""),
                lastName: String($0.split(separator: " ").last ?? ""),
                segment: "Gold"
            )
        }
    )
}

#Preview("Under way — the rule on the row") {
    // 12:00 to 13:00, five minutes in: the rule lands just under the top of
    // the card, and the start hour steps aside for it.
    let start = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now) ?? .now
    let now = start.addingTimeInterval(5 * 60)

    return VStack(alignment: .leading, spacing: 10) {
        EventRow(
            event: previewEvent(id: "1", status: "PLANNED", reason: "BACK_IN_STOCK",
                                name: "Inès Haddad", title: "Essayage", hour: 12, duration: 60),
            standing: .upcoming,
            rule: DayTimeline.NowRule(date: now, progress: 5.0 / 60.0)
        )
        EventRow(
            event: previewEvent(id: "2", status: "PLANNED", reason: "FOLLOW_UP",
                                name: "Marie Dupont", title: "Essayage", hour: 16, duration: 30),
            standing: .upcoming
        )
    }
    .padding(16)
    .background(Color(.Base.canvas))
}

#Preview("Three standings") {
    VStack(alignment: .leading, spacing: 10) {
        EventRow(
            event: previewEvent(id: "1", status: "PLANNED", reason: "BACK_IN_STOCK",
                                name: "Inès Haddad", title: "Retrait commande", hour: 9, duration: 30),
            standing: .done
        )
        EventRow(
            event: previewEvent(id: "2", status: "CANCELLED", reason: "FOLLOW_UP",
                                name: "Marie Dupont", title: "Essayage", hour: 10, duration: 30),
            standing: .cancelled
        )
        EventRow(
            event: previewEvent(id: "3", status: "CONFIRMED", reason: "FOLLOW_UP",
                                name: "Salomé Kaliny", title: "Essayage", hour: 14, duration: 60),
            standing: .upcoming
        )
    }
    .padding(16)
    .background(Color(.Base.canvas))
}

#Preview("With a client, and without") {
    VStack(alignment: .leading, spacing: 10) {
        EventRow(
            event: previewEvent(id: "1", status: "CONFIRMED", reason: "FOLLOW_UP",
                                name: "Salomé Kaliny", title: "Essayage", hour: 14, duration: 60),
            standing: .upcoming
        )
        // No client, so the title takes the first line and the mark is the only
        // thing that says what this is. An avatar had nothing to put here.
        EventRow(
            event: previewEvent(id: "2", status: "PLANNED", reason: "COLLECTION_LAUNCH",
                                name: nil, title: "Essayage collection automne", hour: 16, duration: 45),
            standing: .upcoming
        )
    }
    .padding(16)
    .background(Color(.Base.canvas))
}

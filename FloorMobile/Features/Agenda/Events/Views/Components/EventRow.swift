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
                    .font(.system(size: 11, weight: .medium))
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
        HStack(spacing: 0) {
            // The reason's colour, as drawn in Figma: a short tick at the top of
            // the leading edge, mostly cut away by the corner radius.
            Rectangle()
                .fill(event.reason.fillColor)
                .frame(width: 4, height: 10)
                .opacity(standing.isDimmed ? 0.28 : 1)

            inner
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var inner: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(event.clientDisplayName ?? event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(standing.isDimmed ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textPrimary))
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(standing.isDimmed ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textSecondary))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(trailingLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color(.OnSurface.textTertiary))
                .fixedSize()
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
    }

    private var avatar: some View {
        Circle()
            .fill(Color(.OnSurface.surfaceFaint))
            .frame(width: 36, height: 36)
            .overlay {
                Text((event.clientDisplayName ?? event.title).initials)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(standing.isDimmed ? Color(.OnSurface.textTertiary) : Color(.OnSurface.textSecondary))
            }
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
    name: String,
    title: String,
    hour: Int,
    duration: Int
) -> AgendaEvent {
    AgendaEvent(
        id: id, statusRaw: status, reasonRaw: reason, meetingTypeRaw: "IN_PERSON",
        title: title,
        startDate: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now,
        duration: duration, createdAt: .now, updatedAt: .now,
        client: ClientSummary(firstName: String(name.split(separator: " ").first ?? ""),
                              lastName: String(name.split(separator: " ").last ?? ""),
                              segment: "Gold")
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

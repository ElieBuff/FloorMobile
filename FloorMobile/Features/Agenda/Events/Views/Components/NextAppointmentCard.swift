//
//  NextAppointmentCard.swift
//  FloorMobile
//

import SwiftUI

/// The dark "next appointment" card shown on Home when there is one today:
/// start time and countdown on the left, client and location in the middle,
/// a "Prepare" action on the right. Pulled out of `NextAppointmentSection`
/// once it grew past a one-liner, the same way `AIActionRow` lives on its
/// own next to `AIRecommendationsSection`.
struct NextAppointmentCard: View {
    let event: AgendaEvent
    var onPrepare: () -> Void = {}

    /// Injected so the countdown is testable and previewable at a fixed
    /// instant instead of drifting with the wall clock.
    var now: Date = .now

    var body: some View {
        HStack(spacing: 14) {
            when
            divider
            text
            prepareButton
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 15)
        .cardStyle(surface: Color(.Base.ink))
    }

    private var when: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(event.startDate, format: .dateTime.hour().minute())
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(.OnCanvas.textPrimary))

            if let countdownLabel = event.countdownLabel(from: now) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(.Accent.countdown))
                        .frame(width: 6, height: 6)
                    Text(countdownLabel)
                        .eyebrow()
                        .foregroundStyle(Color(.Accent.countdown))
                }
            }
        }
        .fixedSize()
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.OnCanvas.surfaceSubtle))
            .frame(width: 1)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let clientDisplayName = event.clientDisplayName {
                Text(clientDisplayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.OnCanvas.textPrimary))
                    .lineLimit(1)
            } else {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.OnCanvas.textPrimary))
                    .lineLimit(1)
            }
            if let meetingSummary = event.meetingSummary {
                Text(meetingSummary)
                    .font(.caption2)
                    .foregroundStyle(Color(.OnCanvas.textTertiary))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var prepareButton: some View {
        Button(action: onPrepare) {
            Text("Prepare")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color(.Base.ink))
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(Color(.Base.paper), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("In person, with countdown") {
    NextAppointmentCard(
        event: AgendaEvent(
            id: "1", statusRaw: "PLANNED", reasonRaw: "APPOINTMENT",
            title: "Essayage collection automne",
            startDate: Date(timeIntervalSince1970: 1_788_377_164).addingTimeInterval(25 * 60),
            duration: 45, createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Marie", lastName: "Dupont"),
            store: StoreSummary(storeCode: "VIC")
        ),
        now: Date(timeIntervalSince1970: 1_788_377_164)
    )
    .padding()
    .background(Color.black)
}

#Preview("Starting now, no countdown") {
    NextAppointmentCard(
        event: AgendaEvent(
            id: "2", statusRaw: "PLANNED", reasonRaw: "VIDEO_CALL",
            title: "Point collection",
            startDate: .now, duration: 30, createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Raphaël", lastName: "Van den Berg")
        )
    )
    .padding()
    .background(Color.black)
}

//
//  TaskRow.swift
//  FloorMobile
//

import SwiftUI

/// A single task row inside a day's tasks card: a tinted icon for the task's
/// `Reason`, the category label, the task title, the client, and a checkbox.
/// Lives on its own next to `DayTasksSection`, the same way `AIActionRow` sits
/// beside `AIRecommendationsSection`.
///
/// Unlike `NextAppointmentCard`, this row has no background of its own — in
/// the Figma design every row shares one card, separated by thin dividers,
/// so the card chrome belongs to `DayTasksSection`, not to each row.
struct TaskRow: View {
    let task: AgendaTask
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                icon
                text
                Spacer(minLength: 8)
                checkbox
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var icon: some View {
        task.reason.icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(task.reason.fillColor)
            .frame(width: 36, height: 36)
            .background(task.reason.tintColor, in: RoundedRectangle(cornerRadius: AppRadius.small))
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.reason.displayLabel)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(task.reason.fillColor)
            Text(task.title)
                .font(.system(size: 15))
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .lineLimit(1)
            if let clientDisplayName = task.clientDisplayName {
                Text(clientDisplayName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(.OnSurface.textSecondary))
                    .lineLimit(1)
            }
        }
    }

    private var checkbox: some View {
        Circle()
            .strokeBorder(Color(.Base.ink).opacity(0.25), lineWidth: 1.5)
            .frame(width: 22, height: 22)
    }
}

// MARK: - Previews

#Preview("With client") {
    TaskRow(task: AgendaTask(
        id: "1", statusRaw: "TODO", reasonRaw: "BIRTHDAY", title: "Send diamond-earrings quote",
        startDate: .now, createdAt: .now, updatedAt: .now,
        client: ClientSummary(firstName: "Léa", lastName: "Bonnet")
    ))
    .padding()
    .background(Color(.OnCanvas.surface))
}

#Preview("Every reason") {
    VStack(spacing: 0) {
        ForEach(Reason.allCases, id: \.self) { reason in
            TaskRow(task: AgendaTask(
                id: reason.rawValue, statusRaw: "TODO", reasonRaw: reason.rawValue,
                title: "Example task for \(reason.displayLabel)",
                startDate: .now, createdAt: .now, updatedAt: .now,
                client: ClientSummary(firstName: "Camille", lastName: "Fontaine")
            ))
            if reason != Reason.allCases.last {
                Rectangle()
                    .fill(Color(.OnSurface.borderSubtle))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
        }
    }
    .background(Color(.OnCanvas.surface), in: RoundedRectangle(cornerRadius: AppRadius.large))
    .padding()
    .background(Color.black)
}

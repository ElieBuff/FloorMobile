//
//  AIActionRow.swift
//  FloorMobile
//

import SwiftUI

/// A single AI action as an expandable card. Collapsed it shows the title
/// only; expanded it reveals the reason and the client it concerns. Expansion
/// is driven by the parent so the list can enforce one-open-at-a-time.
struct AIActionRow: View {
    let action: AIAction
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(action.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.textSecondary))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(action.reason)
                            .font(.footnote)
                            .foregroundStyle(Color(.textSecondary))
                        if let name = action.clientDisplayName {
                            Text(name)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color(.textPrimary))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.cardBackground), in: RoundedRectangle(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(Color(.controlStroke), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(isExpanded ? "Collapse recommendation" : "Expand recommendation"))
    }
}

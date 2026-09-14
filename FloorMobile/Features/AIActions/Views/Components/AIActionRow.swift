//
//  AIActionRow.swift
//  FloorMobile
//

import SwiftUI

/// A single AI action, in one of two entirely different layouts driven by
/// `isExpanded` — a compact one-line row, or the full card with the
/// product, its client, and quick actions. Both live in this one view (not
/// two swapped view types) so the row keeps its identity in the list: the
/// card grows and shrinks in place instead of cutting from one look to the
/// other. Expansion itself is driven by the parent, which enforces
/// one-open-at-a-time.
struct AIActionRow: View {
    let action: AIAction
    let isExpanded: Bool
    let onTap: () -> Void
    var onMessage: () -> Void = {}
    var onCall: () -> Void = {}
    var onCreateTask: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        if isExpanded {
            openCard
        } else {
            compactRow
        }
    }

    // MARK: - Compact ("Action row / compact" in Figma)

    private var compactRow: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(.Base.ink))
                    .frame(width: 8, height: 8)
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.categoryLabel ?? action.type)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(.OnLight.textSecondary))
                    Text(action.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.OnLight.textPrimary))
                        .lineLimit(2)
                    if let clientDisplayName = action.clientDisplayName {
                        Text(clientDisplayName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.OnLight.textSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.Base.ink))
            }
            .padding(.leading, 16)
            .padding(.trailing, 18)
            .padding(.vertical, 14)
            .background(Color(.OnDark.surfaceMedium), in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 9, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Expand recommendation"))
    }

    // MARK: - Open ("Action card / open" in Figma)

    private var openCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                statusRow
                bodyRow
                    .padding(.top, 12)
            }
            // A dedicated tap target so it doesn't compete with the quick
            // action buttons below for the same gesture.
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            quickActionsRow
                .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color(.OnDark.surfaceMedium), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color(.Base.paper).opacity(0.9), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 13, y: 10)
        .accessibilityElement(children: .contain)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(.Base.ink))
                .frame(width: 8, height: 8)
            Text(action.categoryLabel ?? action.type)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.72)
                .textCase(.uppercase)
                .foregroundStyle(Color(.OnLight.textSecondary))
        }
    }

    private var bodyRow: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(.OnLight.textPrimary))
                if let clientMetaLine = action.clientMetaLine {
                    Text(clientMetaLine)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.OnLight.textSecondary))
                }
                if let productMetaLine = action.productMetaLine {
                    Text(productMetaLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.OnLight.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let productImageURL = action.productImageURL {
                AsyncImage(url: productImageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Color(.OnDark.surfaceSubtle)
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var quickActionsRow: some View {
        HStack(spacing: 0) {
            QuickActionButton(systemImage: "message.fill", label: String(localized: "Message"), style: .filled, action: onMessage)
            QuickActionButton(systemImage: "phone.fill", label: String(localized: "Call"), style: .outlined, action: onCall)
            QuickActionButton(systemImage: "checklist", label: String(localized: "Task"), style: .outlined, action: onCreateTask)
            QuickActionButton(systemImage: "xmark", label: String(localized: "Not now"), style: .outlined, action: onDismiss)
        }
    }
}

/// One circular button in the open card's quick-actions row: `.filled` is
/// the dark "primary" treatment (Message, the one action worth defaulting
/// to), `.outlined` is the neutral white circle the other three share.
private struct QuickActionButton: View {
    enum Style {
        case filled
        case outlined
    }

    let systemImage: String
    let label: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
                    .frame(width: 50, height: 50)
                    .background(backgroundColor, in: Circle())
                    .shadow(color: .black.opacity(style == .filled ? 0.18 : 0), radius: 9, y: 6)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(.Base.ink).opacity(0.85))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        style == .filled ? Color(.Base.ink) : Color(.Base.paper)
    }

    private var iconColor: Color {
        style == .filled ? Color(.Base.paper) : Color(.Base.ink)
    }
}

// MARK: - Previews

#Preview("Compact") {
    AIActionRow(
        action: .preview,
        isExpanded: false,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("Open — with product") {
    AIActionRow(
        action: .previewWithProduct,
        isExpanded: true,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("Open — no product yet") {
    AIActionRow(
        action: .preview,
        isExpanded: true,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

extension AIAction {
    fileprivate static var preview: AIAction {
        AIAction(
            id: "01PREVIEW",
            agentKey: "awaiting-reply",
            type: "AWAITING_REPLY",
            title: "Asked about the pearl minaudière in ivory",
            reason: "The client asked a question three days ago and has had no reply yet.",
            statusRaw: "PENDING",
            createdAt: .now,
            client: PersonSummary(firstName: "Inès", lastName: "Haddad"),
            categoryLabel: "Awaiting your reply"
        )
    }

    fileprivate static var previewWithProduct: AIAction {
        AIAction(
            id: "01PREVIEW2",
            agentKey: "contact-radar",
            type: "BACK_IN_STOCK",
            title: "The beaded cream dress she tried in June is back in her size.",
            reason: "The item she tried on is back in stock in her size.",
            statusRaw: "PENDING",
            createdAt: .now,
            client: PersonSummary(firstName: "Salomé", lastName: "Kaliny", tier: "Gold"),
            categoryLabel: "Back in stock",
            productName: "Beaded cream dress",
            productSize: "38",
            productPrice: 2400,
            productCurrencyCode: "EUR"
        )
    }
}

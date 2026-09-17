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

    // Geometry of the header block — the dot, the eyebrow and the gap down to
    // the title. Both layouts read these, which is what pins the dot: change one
    // here and the two states stay in step.

    /// Dot to eyebrow. The eyebrow is the only thing the dot pushes right:
    /// everything below starts at the card's own leading edge, so the two
    /// layouts share a single left edge for all their text.
    private static let dotSpacing: CGFloat = 8
    private static let leadingPadding: CGFloat = 16
    private static let topPadding: CGFloat = 14
    /// Vertical spacing between the stacked header lines (eyebrow, title, client).
    private static let headerLineSpacing: CGFloat = 2
    
    
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
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Self.headerLineSpacing) {
                    eyebrowLine
                    Text(action.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.OnSurface.textPrimary))
                        .lineLimit(2)
                    if let clientDisplayName = action.clientDisplayName {
                        Text(clientDisplayName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.OnSurface.textSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.Base.ink))
            }
            .padding(.leading, Self.leadingPadding)
            .padding(.trailing, 18)
            .padding(.vertical, Self.topPadding)
            .cardStyle(shadow: .low)
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
                // Same eyebrow line, same top padding, same gap down to the
                // title as the compact row: that is what keeps the dot — and
                // the header with it — from shifting when the card opens.
                eyebrowLine
                bodyRow
                    .padding(.top, Self.headerLineSpacing)
            }
            // A dedicated tap target so it doesn't compete with the quick
            // action buttons below for the same gesture.
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            quickActionsRow
                .padding(.top, 16)
        }
        .padding(.leading, Self.leadingPadding)
        .padding(.trailing, 20)
        .padding(.top, Self.topPadding)
        .padding(.bottom, 18)
        .agentCardStyle()
        .accessibilityElement(children: .contain)
    }

    private var bodyRow: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(.OnSurface.textPrimary))
                if let clientMetaLine = action.clientMetaLine {
                    Text(clientMetaLine)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.OnSurface.textSecondary))
                }
                if let productMetaLine = action.productMetaLine {
                    Text(productMetaLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.OnSurface.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let productImageURL = action.productImageURL {
                ProductThumbnail(url: productImageURL)
            }
        }
    }

    /// The agent's mark and the category eyebrow, as siblings on one line.
    ///
    /// The dot marks provenance, not state, so it must not move when the card
    /// opens. Centred on the eyebrow it cannot: the eyebrow sits at a fixed
    /// offset from the card's top edge in both layouts, while anything lower —
    /// the title, the row's own mid-height — depends on how much text the state
    /// holds. Plain `.center` alignment is enough precisely because the dot is
    /// paired with the eyebrow alone.
    private var eyebrowLine: some View {
        HStack(spacing: Self.dotSpacing) {
            BreathingDot(seed: action.id, isPaused: isExpanded)
            categoryLabel
        }
    }

    /// The category eyebrow, shared by both layouts so the two never drift apart.
    private var categoryLabel: some View {
        Text(action.categoryLabel ?? action.type)
            .font(.system(size: 10, weight: .medium))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Color(.OnSurface.textSecondary))
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
            client: ClientSummary(firstName: "Inès", lastName: "Haddad"),
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
            client: ClientSummary(firstName: "Salomé", lastName: "Kaliny", segment: "Gold"),
            categoryLabel: "Back in stock",
            productName: "Beaded cream dress",
            productSize: "38",
            productPrice: 2400,
            productCurrencyCode: "EUR"
        )
    }
}

//
//  QuickActionButton.swift
//  FloorMobile
//

import SwiftUI

/// A circular icon button with a caption underneath, for a row of primary
/// quick actions (Message, Call, …). `.filled` is the dark "primary" treatment
/// for the one action worth defaulting to; `.outlined` is the neutral white
/// circle the others share.
struct QuickActionButton: View {
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
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 50, height: 50)
                    .background(backgroundColor, in: Circle())
                    .shadow(style == .filled ? .control : .none)
                Text(label)
                    .font(.caption2)
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

#Preview {
    HStack(spacing: 0) {
        QuickActionButton(systemImage: "message.fill", label: "Message", style: .filled) {}
        QuickActionButton(systemImage: "phone.fill", label: "Call", style: .outlined) {}
        QuickActionButton(systemImage: "xmark", label: "Not now", style: .outlined) {}
    }
    .padding()
    .background(Color(.OnCanvas.surface))
}

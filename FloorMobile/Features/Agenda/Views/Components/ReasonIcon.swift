//
//  ReasonIcon.swift
//  FloorMobile
//

import SwiftUI

/// A reason's glyph on its own tinted square — the badge that opens a task row
/// and names the reason in the picker.
///
/// The two have to be the same object: the picker is where the advisor learns
/// which mark means which reason, and the row is where that learning is spent.
struct ReasonIcon: View {
    let reason: Reason

    var body: some View {
        reason.icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(reason.fillColor)
            .frame(width: 36, height: 36)
            .background(reason.tintColor, in: RoundedRectangle(cornerRadius: AppRadius.small))
    }
}

// MARK: - Previews

#Preview("Every reason") {
    HStack(spacing: 9) {
        ForEach(Reason.allCases, id: \.self) { ReasonIcon(reason: $0) }
    }
    .padding(24)
    .background(Color(.Base.canvas))
}

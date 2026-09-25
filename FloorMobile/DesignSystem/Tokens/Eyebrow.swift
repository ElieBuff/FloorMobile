//
//  Eyebrow.swift
//  FloorMobile
//

import SwiftUI

/// The small uppercase line that names a category above a title — the reason
/// over a task, the agent's tag over a recommendation, the countdown over a
/// start time.
///
/// One modifier because the three sites had drifted into three near-copies of
/// the same four lines, and because the type size is the one thing here that
/// must not be a number: `caption2` is Apple's smallest text style and the HIG
/// floor of 11pt, and it scales with Dynamic Type where the mockup's 10pt did
/// not. The tracking is what makes a tiny uppercase line legible, and it stays
/// a point value on purpose — it is letter-spacing, not type size.
///
/// ```swift
/// Text(action.categoryLabel).eyebrow()
/// Text(task.reason.displayLabel).eyebrow(weight: .bold, tracking: 1.2)
/// ```
struct Eyebrow: ViewModifier {
    var weight: Font.Weight = .medium
    var tracking: CGFloat = 0.8

    func body(content: Content) -> some View {
        content
            .font(.caption2.weight(weight))
            .tracking(tracking)
            .textCase(.uppercase)
    }
}

extension View {
    /// Styles this text as an eyebrow: `caption2`, uppercase, tracked. The
    /// colour is the call site's — an eyebrow reads grey on a card and accent
    /// on a countdown.
    func eyebrow(weight: Font.Weight = .medium, tracking: CGFloat = 0.8) -> some View {
        modifier(Eyebrow(weight: weight, tracking: tracking))
    }
}

// MARK: - Previews

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("Back in stock").eyebrow()
            .foregroundStyle(Color(.OnSurface.textSecondary))
        Text("Follow-up").eyebrow(weight: .bold, tracking: 1.2)
            .foregroundStyle(Reason.followUp.fillColor)
        Text("In 25 min").eyebrow()
            .foregroundStyle(Color(.Accent.countdown))
    }
    .padding(24)
    .background(Color(.OnCanvas.surface))
}

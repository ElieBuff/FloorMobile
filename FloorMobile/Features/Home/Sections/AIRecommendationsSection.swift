//
//  AIRecommendationsSection.swift
//  FloorMobile
//

import SwiftUI
import os

/// Home section surfacing AI recommendations. Placeholder: no data yet,
/// the action only logs until the recommendations screen exists.
struct AIRecommendationsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "AI recommendations"),
                actionLabel: String(localized: "View all")
            ) {
                AppLog.ui.info("Home: 'View all' tapped in AI recommendations")
            }
            EmptySectionCard(
                icon: { Image(systemName: "sparkles").foregroundStyle(Color(.textPrimary)) },
                message: String(localized: "No recommendation yet")
            )
        }
    }
}

#Preview {
    AIRecommendationsSection()
        .padding()
        .background(Color.black)
}

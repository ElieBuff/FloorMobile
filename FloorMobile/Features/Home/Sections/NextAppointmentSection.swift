//
//  NextAppointmentSection.swift
//  FloorMobile
//

import SwiftUI
import os

/// Home section showing the advisor's next appointment. Placeholder: no
/// data yet, the action only logs until the agenda screen exists.
struct NextAppointmentSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Next appointment"),
                actionLabel: String(localized: "View agenda")
            ) {
                AppLog.ui.info("Home: 'View agenda' tapped in Next appointment")
            }
            EmptySectionCard(
                icon: { Image(systemName: "calendar").foregroundStyle(Color(.textPrimary)) },
                message: String(localized: "No appointment today"),
                action: EmptySectionAction(label: String(localized: "View agenda")) {
                    AppLog.ui.info("Home: card 'View agenda' tapped in Next appointment")
                }
            )
        }
    }
}

#Preview {
    NextAppointmentSection()
        .padding()
        .background(Color.black)
}

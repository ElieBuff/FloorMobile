//
//  TodaysTasksSection.swift
//  FloorMobile
//

import SwiftUI
import os

/// Home section listing today's tasks. Placeholder: no data yet, both
/// actions only log until the agenda and task screens exist.
struct TodaysTasksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Today's tasks"),
                actionLabel: String(localized: "View agenda")
            ) {
                AppLog.ui.info("Home: 'View agenda' tapped in Today's tasks")
            }
            EmptySectionCard(
                icon: { Image(systemName: "checklist").foregroundStyle(Color(.textPrimary)) },
                message: String(localized: "No task today"),
                action: EmptySectionAction(label: String(localized: "Create task"), systemImage: "plus") {
                    AppLog.ui.info("Home: 'Create task' tapped in Today's tasks")
                }
            )
        }
    }
}

#Preview {
    TodaysTasksSection()
        .padding()
        .background(Color.black)
}

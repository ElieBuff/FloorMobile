//
//  ProfileSummarySection.swift
//  FloorMobile
//

import SwiftUI

/// Who the client is in a few lines, and the next step advised with them, at
/// the top of the profile's "Profile" tab: the brief and the next step of
/// their AI summary (`ClientProfile.summary`).
///
/// While the summary is written — up to 40 s — grey bars stand in for it. A
/// summary that failed hides the section: the page's one notice says so.
struct ProfileSummarySection: View {
    let summary: Loadable<ClientSummary>

    var body: some View {
        if summary.error == nil {
            Section {
                if let summary = summary.value {
                    // Plain text: a stacked row would put an empty label above it.
                    Text(summary.brief)
                        .foregroundStyle(Color(.OnSurface.textPrimary))
                        .listRowInsets(.cardRow)
                    DetailStackedRow(label: String(localized: "Next step"), text: summary.nextStep)
                        .listRowInsets(.cardRow)
                } else {
                    SkeletonLines(widths: [1, 0.9, 0.55])
                        .listRowInsets(.cardRow)
                    SkeletonLines(widths: [0.3, 0.8])
                        .listRowInsets(.cardRow)
                }
            } header: {
                Text("Summary")
            }
        }
    }
}

//
//  ProfileTimelineSection.swift
//  FloorMobile
//

import SwiftUI

/// One list of the client's timeline (`ClientProfile.timeline`), in the
/// profile's "Activity" tab: "Upcoming" — what is planned with them — then
/// "Recent activity" — what happened —, the same section on each of its two
/// lists. Named after the server's `timeline`.
///
/// While the timeline is on its way, grey bars stand in for its lines; once
/// in, its lines, or a word that there are none. A timeline that failed hides
/// the section: the page's one notice says so.
struct ProfileTimelineSection: View {
    /// The section's header, e.g. "Upcoming".
    let title: String
    let timeline: Loadable<ClientTimeline>
    /// Which of the timeline's two lists the section shows.
    let lines: KeyPath<ClientTimeline, [ClientTimelineItem]>
    /// What the section says when its list is empty, e.g. "Nothing planned".
    let emptyMessage: String

    var body: some View {
        if timeline.error == nil {
            Section {
                if let items = timeline.value?[keyPath: lines] {
                    if items.isEmpty {
                        Text(emptyMessage)
                            .foregroundStyle(Color(.OnSurface.textSecondary))
                            .listRowInsets(.cardRow)
                    } else {
                        ForEach(items) { item in
                            ClientTimelineRow(item: item)
                                .listRowInsets(.cardRow)
                        }
                    }
                } else {
                    // A row's title over its subtitle, three times.
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonLines(widths: [0.7, 0.45])
                            .listRowInsets(.cardRow)
                    }
                }
            } header: {
                Text(title)
            }
        }
    }
}

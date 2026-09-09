//
//  HomeView.swift
//  FloorMobile
//

import SwiftUI

/// The home screen: a summary of the sections a store advisor sees first.
/// Each section is its own view in `Sections/`, so it can grow (data,
/// states, navigation) without crowding this file.
struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                AIRecommendationsSection()
                NextAppointmentSection()
                TodaysTasksSection()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .ambientBackground()
    }
}

#Preview {
    HomeView()
}

//
//  ProfileConsentsSection.swift
//  FloorMobile
//

import SwiftUI

/// What the client agreed to be reached by, channel by channel, in the
/// profile's "Profile" tab — from the card on screen (`ClientItem.optIns`), so
/// shown once a card carries them: at once for the associate's own clients,
/// with the details for a client of the brand.
struct ProfileConsentsSection: View {
    let optIns: ClientItem.OptIns

    var body: some View {
        Section {
            ForEach(ClientItem.OptIns.Channel.allCases, id: \.self) { channel in
                DetailRow(label: channel.label, value: optIns.answer(for: channel))
                    .listRowInsets(.cardRow)
            }
        } header: {
            Text("Consents")
        }
    }
}

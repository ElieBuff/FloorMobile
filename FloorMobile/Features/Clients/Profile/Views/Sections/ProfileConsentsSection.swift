//
//  ProfileConsentsSection.swift
//  FloorMobile
//

import SwiftUI

/// What the client agreed to be reached by, channel by channel, in the
/// profile's "Profile" tab — from their details (`ClientDetails.optIns`), so
/// shown once those are in.
struct ProfileConsentsSection: View {
    let optIns: ClientDetails.OptIns

    var body: some View {
        Section {
            row(String(localized: "Email"), optIns.email)
            row(String(localized: "Messages"), optIns.directMessage)
            row(String(localized: "Phone call"), optIns.call)
            row(String(localized: "WeChat"), optIns.wechat)
            row(String(localized: "LINE"), optIns.line)
        } header: {
            Text("Consents")
        }
    }

    private func row(_ channel: String, _ agreed: Bool) -> some View {
        DetailRow(label: channel, value: agreed ? String(localized: "Yes") : String(localized: "No"))
            .listRowInsets(.cardRow)
    }
}

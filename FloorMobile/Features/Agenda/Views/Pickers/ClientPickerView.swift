//
//  ClientPickerView.swift
//  FloorMobile
//

import SwiftUI

/// Who a task or an appointment is for.
///
/// The shell only. Nothing lists clients here yet, so the screen says so
/// rather than pretending to look and finding nothing. It exists now because
/// the row that opens it is a `NavigationLink`, and a link needs somewhere to
/// go. Once picking a client is built, the screen lists the server's clients
/// — the device keeps none — in place of the `ContentUnavailableView`, and
/// nothing above this file changes.
struct ClientPickerView: View {
    @Binding var selection: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("No clients yet")
            } icon: {
                Image(systemName: "person.2")
            }
        } description: {
            Text("Client search arrives with the Clients tab.")
        }
        .ambientBackground()
        .navigationTitle(Text("Client"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var client = ""

    return NavigationStack {
        ClientPickerView(selection: $client)
    }
    .tint(Color(.Base.ink))
}

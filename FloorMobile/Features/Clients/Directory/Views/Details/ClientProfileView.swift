//
//  ClientProfileView.swift
//  FloorMobile
//

import SwiftUI
import os

/// A client's profile — the 360 view — pushed from any client list: what the
/// server holds on them, asked for each time the page opens.
///
/// Takes an id, because a route carries ids and never a list's value
/// (`ClientsRoute`). Today the page only shows the client's card; each section
/// the profile gains comes with its own fields in `ClientProfile`.
///
/// Opening the page also records the view, for the associate's recent
/// clients, by the route's rules: once per navigation — a pushed page is a new
/// view, with a new `viewRecorded`, so coming back to the tab or from a screen
/// the profile opened does not send it again — in a task the screen never
/// waits on, and that outlives the page. Never queued offline: the endpoint is
/// interactive (`Endpoint.recordClientView`).
struct ClientProfileView: View {
    let clientID: String

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services

    @State private var profile: ClientProfile?
    /// Why the profile could not be loaded; its error stands in for the page.
    @State private var failure: (any Error)?
    /// Whether this navigation already recorded its view.
    @State private var viewRecorded = false

    var body: some View {
        content
            .ambientBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: recordViewOnce)
    }

    /// The profile once loaded; until then a spinner that loads it, or the
    /// error of a load that failed. Separate branches, so "Try again" — which
    /// clears the error — brings the spinner back, and with it a new load.
    /// A profile already loaded is not asked for again when the page
    /// reappears.
    @ViewBuilder
    private var content: some View {
        if let profile {
            ClientProfileContent(profile: profile)
        } else if let failure {
            LoadFailureView(title: String(localized: "Couldn't load this client"), error: failure) {
                self.failure = nil
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await load() }
        }
    }

    /// The client's name once the profile is in, empty until then.
    private var title: String {
        profile?.client.displayLabel ?? ""
    }

    private func load() async {
        do {
            profile = try await services.clients.profile(id: clientID, using: session.api)
        } catch {
            // Leaving the tab cancels the load, which `APIClient` reports as a
            // network error: not a failure to show when the page comes back.
            guard !Task.isCancelled else { return }
            failure = error
        }
    }

    /// Records this navigation's view, once, without making the screen wait:
    /// the recent clients the server answers with are kept in the background.
    /// A failure — no network, an unknown client — is logged, never shown:
    /// the associate has the profile to read, not a view to retry.
    private func recordViewOnce() {
        guard !viewRecorded else { return }
        viewRecorded = true
        let clients = services.clients
        let api = session.api
        let id = clientID
        Task {
            do {
                try await clients.recordView(of: id, using: api)
            } catch {
                AppLog.sync.error(
                    "Recording a client view failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

/// What the profile shows once loaded: who the client is, then how to reach
/// them and where they belong. A view of its own so a preview can show it on
/// a made-up profile, without a server.
private struct ClientProfileContent: View {
    let profile: ClientProfile

    private var client: ClientItem { profile.client }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    InitialsAvatar(name: client.displayName ?? "", size: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.displayLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(.OnSurface.textPrimary))

                        if let segment = client.segment, !segment.isEmpty {
                            Text(segment)
                                .font(.subheadline)
                                .foregroundStyle(Color(.OnSurface.textSecondary))
                        }
                    }

                    Spacer(minLength: 0)
                }
                // One element for VoiceOver: the name, then the segment. The
                // avatar stays hidden, the name it abbreviates is beside it.
                .accessibilityElement(children: .combine)
                .listRowInsets(.cardRow)
            }

            Section {
                row(String(localized: "Email"), client.primaryEmail)
                row(String(localized: "Phone"), client.primaryPhone)
                row(String(localized: "Store"), client.storeName)
                row(String(localized: "Sales associate"), client.salesAssociateName)
            }
        }
        .cardList()
    }

    /// A field the client has; nothing for one they do not — a missing email
    /// is not worth a line here.
    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            DetailRow(label: label, value: value)
                .listRowInsets(.cardRow)
        }
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        ClientProfileContent(profile: ClientProfile(client: ClientItem(
            id: "1", displayName: "Alice Martinez", segment: "VIC",
            storeCode: "90917634296", storeName: "Regent Street",
            salesAssociateExternalId: "378970372512460673", salesAssociateName: "Elie Buff",
            primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
        )))
        .ambientBackground()
        .navigationTitle("Alice Martinez")
        .navigationBarTitleDisplayMode(.inline)
    }
}

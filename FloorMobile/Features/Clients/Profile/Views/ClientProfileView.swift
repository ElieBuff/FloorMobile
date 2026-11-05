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
/// (`ClientsRoute`). Under the client's name, two tabs of sections
/// (`Sections/`): "Profile", who the client is, and "Activity", what happens
/// with them. Only the details show real data today, loaded alone; each other
/// section will come from a part of `ClientProfile` — its AI summary or its
/// timeline — once the page adopts it.
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

    @State private var profile: ClientDetails?
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
            profile = try await services.clients.details(id: clientID, using: session.api)
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

/// What the profile shows once loaded: who the client is, the tabs, then the
/// sections of the tab picked. A view of its own so a preview can show it on
/// a made-up profile, without a server.
private struct ClientProfileContent: View {
    let profile: ClientDetails

    /// The two halves of the profile.
    private enum Tab: Hashable {
        /// Who the client is: summary, details, dates, household, tastes,
        /// lists, purchases and notes.
        case profile
        /// What happens with them: key figures, what is planned, what
        /// happened.
        case activity
    }

    /// The tab shown; "Profile" when the page opens.
    @State private var tab = Tab.profile

    private var client: ClientItem { profile.client }

    var body: some View {
        List {
            header

            Section {
                Picker(String(localized: "Section"), selection: $tab) {
                    Text("Profile").tag(Tab.profile)
                    Text("Activity").tag(Tab.activity)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            switch tab {
            case .profile:
                ProfileSummarySection()
                ProfileDetailsSection(client: client)
                ProfileImportantDatesSection()
                ProfileHouseholdSection()
                ProfilePreferencesSection()
                ProfileWaitlistSection()
                ProfileWishlistSection()
                ProfilePurchasesSection()
                ProfileNotesSection()
            case .activity:
                ProfileMetricsSection()
                ProfileUpcomingActivitiesSection()
                ProfileTimelineSection()
            }
        }
        .cardList()
    }

    /// The client's avatar, name and segment, above the tabs.
    private var header: some View {
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
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        ClientProfileContent(profile: ClientDetails(
            client: ClientItem(
                id: "1", displayName: "Alice Martinez", segment: "VIC",
                storeCode: "90917634296", storeName: "Regent Street",
                salesAssociateExternalId: "378970372512460673", salesAssociateName: "Elie Buff",
                primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
            ),
            salutation: "MRS",
            address: ClientDetails.Address(
                street: "12 Rue du Faubourg Saint-Honoré", postalCode: "75008",
                city: "Paris", state: nil, country: "FR"
            ),
            preferredLanguage: "fr",
            optIns: ClientDetails.OptIns(email: true, directMessage: true, call: false, wechat: false, line: false)
        ))
        .ambientBackground()
        .navigationTitle("Alice Martinez")
        .navigationBarTitleDisplayMode(.inline)
    }
}

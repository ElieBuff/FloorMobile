//
//  ClientProfileView.swift
//  FloorMobile
//

import SwiftUI
import os

/// A client's profile — the 360 view — pushed from any client list: its three
/// parts (`ClientProfile`) — who the client is, their AI summary, their
/// timeline — asked for at once each time the page opens, each shown as soon
/// as it is in.
///
/// Takes an id, and the row the list showed when there is one
/// (`ClientsRoute.profile`): the page shows that card at once, under the
/// client's name, until the details replace it. Without a card — a deep link —
/// a spinner waits for the details, and their failure takes the page. Under
/// the name, two tabs of sections (`Sections/`): "Profile", who the client
/// is, and "Activity", what happens with them. A part on its way shows grey
/// bars; a part that failed hides its sections, and one notice above the tabs
/// says so and asks again.
///
/// Opening the page also records the view, for the associate's recent
/// clients, by the route's rules: once per navigation — a pushed page is a new
/// view, with a new `viewRecorded`, so coming back to the tab or from a screen
/// the profile opened does not send it again — in a task the screen never
/// waits on, and that outlives the page. Never queued offline: the endpoint is
/// interactive (`Endpoint.recordClientView`).
struct ClientProfileView: View {
    let clientID: String
    /// The row the list showed, on screen until the details are in; `nil`
    /// from a deep link.
    let card: ClientItem?

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services

    @State private var profile: ClientProfile
    /// Whether this navigation already recorded its view.
    @State private var viewRecorded = false

    init(clientID: String, card: ClientItem? = nil) {
        self.clientID = clientID
        self.card = card
        _profile = State(initialValue: ClientProfile(clientID: clientID))
    }

    var body: some View {
        content
            .ambientBackground()
            .navigationTitle(client?.displayLabel ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: recordViewOnce)
            // Here, on a view that never changes, and not on `content`: the
            // spinner giving way to the profile would cancel the loads under
            // way. Each restarts when its part goes back to `.loading`.
            .task(id: profile.details.isLoading) {
                await load(\.details) { try await services.clients.details(id: clientID, using: session.api) }
            }
            .task(id: profile.summary.isLoading) {
                await load(\.summary) { try await services.clients.summary(id: clientID, using: session.api) }
            }
            .task(id: profile.timeline.isLoading) {
                await load(\.timeline) { try await services.clients.timeline(id: clientID, using: session.api) }
            }
    }

    /// The card shown: the details' once in, else the list's.
    private var client: ClientItem? {
        profile.details.value?.client ?? card
    }

    /// The profile as soon as there is a card to show; until then a spinner,
    /// or the error of details that failed — whose "Try again" asks for them
    /// again.
    @ViewBuilder
    private var content: some View {
        if let client {
            ClientProfileContent(client: client, profile: $profile)
        } else if let error = profile.details.error {
            LoadFailureView(title: String(localized: "Couldn't load this client"), error: error) {
                profile.details = .loading
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Asks for one part while it is on its way, and puts in what comes back.
    /// A part loaded or failed is left as it is: a page coming back does not
    /// ask again for what it has.
    private func load<Value>(
        _ part: WritableKeyPath<ClientProfile, Loadable<Value>>,
        _ fetch: () async throws -> Value
    ) async {
        guard profile[keyPath: part].isLoading else { return }
        do {
            profile[keyPath: part] = .loaded(try await fetch())
        } catch {
            // Leaving the tab cancels the load, which `APIClient` reports as a
            // network error: not a failure — the part stays on its way, asked
            // for again when the page comes back.
            guard !Task.isCancelled else { return }
            profile[keyPath: part] = .failed(error)
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

/// What the profile shows once there is a card: who the client is, the notice
/// of a part that failed, the tabs, then the sections of the tab picked. A
/// view of its own so a preview can show it on a made-up profile, without a
/// server.
private struct ClientProfileContent: View {
    let client: ClientItem
    @Binding var profile: ClientProfile

    /// The two halves of the profile.
    private enum Tab: Hashable {
        /// Who the client is: summary, details, consents, dates, household,
        /// tastes, lists, purchases and notes.
        case profile
        /// What happens with them: key figures, what is planned, what
        /// happened.
        case activity
    }

    /// The tab shown; "Profile" when the page opens.
    @State private var tab = Tab.profile

    var body: some View {
        List {
            header

            if let error = profile.firstError {
                failureNotice(error)
            }

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
                ProfileSummarySection(summary: profile.summary)
                ProfileDetailsSection(client: client, details: profile.details)
                if let details = profile.details.value {
                    ProfileConsentsSection(optIns: details.optIns)
                }
                ProfileImportantDatesSection()
                ProfileHouseholdSection()
                ProfilePreferencesSection()
                ProfileWaitlistSection()
                ProfileWishlistSection()
                ProfilePurchasesSection()
                ProfileNotesSection()
            case .activity:
                ProfileMetricsSection()
                ProfileTimelineSection(
                    title: String(localized: "Upcoming"), timeline: profile.timeline, lines: \.upcoming,
                    emptyMessage: String(localized: "Nothing planned")
                )
                ProfileTimelineSection(
                    title: String(localized: "Recent activity"), timeline: profile.timeline, lines: \.past,
                    emptyMessage: String(localized: "No activity yet")
                )
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

    /// The one notice for every part that failed — their sections hidden —
    /// with why, and "Try again", which asks for all of them again. An
    /// `EmptySectionCard` on the background like the tabs, mounted as
    /// `MyClientsList.fallbackNotice` mounts it for a silent server: keep the
    /// two alike.
    private func failureNotice(_ error: any Error) -> some View {
        Section {
            EmptySectionCard(
                icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color(.OnCanvas.textPrimary))
                        .accessibilityHidden(true)
                },
                message: String(localized: "Part of this profile couldn't be loaded. \(error.localizedDescription)"),
                action: EmptySectionAction(label: String(localized: "Try again")) {
                    profile.retryFailed()
                }
            )
            // One element for VoiceOver: the message, then its button.
            .accessibilityElement(children: .combine)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}

// MARK: - Previews

private let previewClient = ClientItem(
    id: "1", displayName: "Alice Martinez", segment: "VIC",
    storeCode: "90917634296", storeName: "Regent Street",
    salesAssociateExternalId: "378970372512460673", salesAssociateName: "Elie Buff",
    primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
)

#Preview("Loaded") {
    @Previewable @State var profile = ClientProfile(
        clientID: "1",
        details: .loaded(ClientDetails(
            client: previewClient,
            salutation: "misses",
            address: ClientDetails.Address(
                street: "12 Rue du Faubourg Saint-Honoré", postalCode: "75008",
                city: "Paris", state: nil, country: "FR"
            ),
            preferredLanguage: "fr",
            optIns: ClientDetails.OptIns(email: true, directMessage: true, call: false, wechat: false, line: false)
        )),
        summary: .loaded(ClientSummary(
            title: "A loyal outerwear client",
            brief: "With the house since 2022, Alice buys outerwear each season and came for a fitting last week.",
            prose: "",
            nextStep: "Call her about the new coats arriving on Friday.",
            mood: .positive
        )),
        timeline: .loaded(ClientTimeline(
            upcoming: [
                ClientTimelineItem(
                    id: "e1", kind: .event, date: .now.addingTimeInterval(86_400), status: "PLANNED",
                    title: "Fitting", subtitle: [.reason("BACK_IN_STOCK"), .meetingType("IN_PERSON")]
                ),
            ],
            past: [
                ClientTimelineItem(
                    id: "t1", kind: .transaction, date: .now.addingTimeInterval(-604_800), status: "PAID",
                    title: "VESTE ACACIA", subtitle: [.itemCount(1), .amount(890, currency: "EUR")]
                ),
            ]
        ))
    )
    NavigationStack {
        ClientProfileContent(client: previewClient, profile: $profile)
            .ambientBackground()
            .navigationTitle("Alice Martinez")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Loading from a list") {
    @Previewable @State var profile = ClientProfile(clientID: "1")
    NavigationStack {
        ClientProfileContent(client: previewClient, profile: $profile)
            .ambientBackground()
            .navigationTitle("Alice Martinez")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Summary failed") {
    @Previewable @State var profile = ClientProfile(
        clientID: "1", summary: .failed(AppError.server(statusCode: 502))
    )
    NavigationStack {
        ClientProfileContent(client: previewClient, profile: $profile)
            .ambientBackground()
            .navigationTitle("Alice Martinez")
            .navigationBarTitleDisplayMode(.inline)
    }
}

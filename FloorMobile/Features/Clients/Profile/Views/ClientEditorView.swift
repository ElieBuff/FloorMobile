//
//  ClientEditorView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// The form that edits one of the associate's own clients: their names, how
/// to reach them, their address and what they agreed to be reached by — the
/// fields an associate may correct, and nothing else.
///
/// It edits a copy of the card itself (`ClientItem`) rather than a draft: the
/// card's editable fields are `var`s, and its rules say what changed and
/// whether that can go (`hasChanges(from:)`, `isValid(from:)`). Only what
/// changed is sent (`ClientService.update`).
///
/// Consents changed need the client's signature, taken by a sheet over the
/// form when "Save" is tapped. The signature is worth only the consents it
/// was given for: a consent changed after it — say after a failed save —
/// drops it, and the next "Save" asks again. On success the form hands the
/// client as the server answered back to the profile (`onSaved`), and
/// closes; on failure it stays up, what was typed and signed still in it.
struct ClientEditorView: View {
    /// What the associate is editing.
    @State private var client: ClientItem
    /// The client as the form opened on them, what every rule compares with.
    private let original: ClientItem
    private let onSaved: (ClientItem) -> Void

    /// The client's signature under the consents on screen, once they signed.
    @State private var signature: ClientSignature?
    @State private var isSigning = false
    /// While the save is in flight: the confirm button waits rather than
    /// letting a second tap send a second edit.
    @State private var isSaving = false
    @State private var alert: FloorAlert?

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    init(client: ClientItem, onSaved: @escaping (ClientItem) -> Void) {
        _client = State(initialValue: client)
        original = client
        self.onSaved = onSaved
    }

    var body: some View {
        fields
            .composerScreen(
                title: String(localized: "Edit client"),
                placement: .root,
                canSave: client.isValid(from: original) && client.hasChanges(from: original),
                isDirty: client != original,
                isSaving: isSaving
            ) {
                save()
            }
            .onChange(of: client.optIns) { signature = nil }
            .sheet(isPresented: $isSigning) {
                ClientSignatureSheet(client: client, original: original) { signed in
                    signature = signed
                    send()
                }
            }
            .floorAlert($alert)
    }

    /// Whether the consents differ from those the form opened on — what asks
    /// for a signature.
    private var consentsChanged: Bool {
        client.optIns != original.optIns
    }

    /// The address, an empty one standing in for none: its lines bind like
    /// any field, and an address cleared of every line is none again.
    private var address: Binding<ClientItem.Address> {
        $client.address.replacingNil(with: ClientItem.Address())
    }

    // MARK: - Fields

    private var fields: some View {
        List {
            Section("Name") {
                row(String(localized: "First name"), $client.firstName)
                    .textContentType(.givenName)
                row(String(localized: "Last name"), $client.lastName)
                    .textContentType(.familyName)
            }

            Section("Contact") {
                row(String(localized: "Email"), $client.primaryEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !client.isEmailValid(from: original) {
                    Text("Enter a valid email")
                        .font(.footnote)
                        .foregroundStyle(Color(.Status.Tint.error))
                        .listRowInsets(.insetGroupedRowInsets)
                }
                row(String(localized: "Phone"), $client.primaryPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

            Section("Address") {
                row(String(localized: "Street"), address.street)
                    .textContentType(.fullStreetAddress)
                row(String(localized: "Postal code"), address.postalCode)
                    .textContentType(.postalCode)
                row(String(localized: "City"), address.city)
                    .textContentType(.addressCity)
                row(String(localized: "Region"), address.state)
                    .textContentType(.addressState)
                row(String(localized: "Country"), address.country)
                    .textContentType(.countryName)
            }

            // The details always carry the consents; a card without them has
            // nothing to edit here.
            if let optIns = Binding($client.optIns) {
                Section("Consents") {
                    ForEach(ClientItem.OptIns.Channel.allCases, id: \.self) { channel in
                        Toggle(isOn: optIns[dynamicMember: channel.keyPath]) {
                            FieldLabel(channel.label)
                        }
                        .listRowInsets(.insetGroupedRowInsets)
                    }
                }
            }
        }
        .insetGroupedList()
        .listSectionSpacing(16)
        .scrollDismissesKeyboard(.interactively)
    }

    /// One field of the form, bound to an optional value of the card.
    private func row(_ label: String, _ value: Binding<String?>) -> some View {
        FormTextRow(label: label, text: value.replacingNil(with: ""))
            .listRowInsets(.insetGroupedRowInsets)
    }

    // MARK: - Saving

    /// Asks for the client's signature when the consents changed and none
    /// stands for them, else sends.
    private func save() {
        guard !isSaving else { return }
        if consentsChanged && signature == nil {
            isSigning = true
        } else {
            send()
        }
    }

    /// Sends the edit, and closes only once the server has it.
    private func send() {
        guard !isSaving else { return }
        isSaving = true

        let api = session.api
        let clients = services.clients
        let client = client
        let original = original
        let signature = signature

        Task {
            do {
                let saved = try await clients.update(client, from: original, signature: signature, using: api)
                onSaved(saved)
                dismiss()
            } catch {
                isSaving = false
                alert = FloorAlert(
                    kind: .error,
                    title: String(localized: "Client not saved"),
                    message: error.localizedDescription,
                    primary: AlertAction(label: String(localized: "Try again")) { save() },
                    secondary: AlertAction(label: String(localized: "Close"), emphasis: .quiet)
                )
            }
        }
    }
}

// MARK: - Previews

#Preview {
    let container = try! ModelContainer(
        for: Client.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let client = ClientItem(
        id: "1", firstName: "Alice", lastName: "Martinez", segment: "VIC",
        storeCode: "90917634296", storeName: "Regent Street",
        salesAssociateExternalId: "378970372512460673", salesAssociateName: "Elie Buff",
        primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78",
        address: ClientItem.Address(
            street: "12 Rue du Faubourg Saint-Honoré", postalCode: "75008", city: "Paris", state: nil, country: "FR"
        ),
        optIns: ClientItem.OptIns(email: true, directMessage: true, call: false, wechat: false, line: false)
    )

    return NavigationStack {
        ClientEditorView(client: client) { _ in }
    }
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
    .modelContainer(container)
    .tint(Color(.Base.ink))
}

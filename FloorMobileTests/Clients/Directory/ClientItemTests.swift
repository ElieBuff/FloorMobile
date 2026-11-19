//
//  ClientItemTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client item")
struct ClientItemTests {

    private static let address = ClientItem.Address(
        street: "Rua Garrett 50", postalCode: "1200-204", city: "Lisboa", state: nil, country: "PT"
    )

    private static let optIns = ClientItem.OptIns(email: true, directMessage: true, call: false, wechat: false, line: false)

    /// A search fixture page, decoded the way `APIClient` decodes it.
    private static func page(_ fixture: String) throws -> CursorPage<ClientWire.Response> {
        try APIClient.makeDecoder().decode(CursorPage<ClientWire.Response>.self, from: try Fixture.data(fixture))
    }

    // MARK: - From a server card

    @Test("A card without contacts maps onto names, store and associate, with no way to reach the client")
    func cardWithoutContactsMaps() throws {
        let item = ClientItem(wire: try #require(try Self.page("client_search_page").items.first))

        #expect(item.id == "01JBRAND0000000000000000A1")
        #expect(item.displayName == "Nina Larsen")
        #expect(item.segment == "VIC")
        #expect(item.storeCode == "90917667064")
        #expect(item.storeName == "My Custom Location")
        #expect(item.salesAssociateExternalId == "378970372512460673")
        #expect(item.salesAssociateName == "Elie Buff")
        // This card, from a search of the brand, came without them (their profile has them).
        #expect(item.primaryEmail == nil)
        #expect(item.primaryPhone == nil)
        #expect(item.address == nil)
        #expect(item.optIns == nil)
        // Not sent by the search yet: the fixture as served.
        #expect(item.salutation == nil)
        #expect(item.preferredLanguage == nil)
    }

    @Test("A card of the associate's own clients maps with the email and the phone too")
    func mineCardMaps() throws {
        let page = try Self.page("client_my_clients_page")
        let item = ClientItem(wire: try #require(page.items.first))

        #expect(page.nextCursor == "my-clients-cursor-2")
        #expect(item.displayName == "Aliette Martin")
        #expect(item.storeCode == "90917634296")
        #expect(item.storeName == "Shop location")
        #expect(item.salesAssociateExternalId == "seed-sa-001")
        #expect(item.salesAssociateName == "Thomas Torres")
        #expect(item.primaryEmail == "seed.client.375493@example.test")
        #expect(item.primaryPhone == "+33612345678")
    }

    @Test("A card with nothing but its ids maps to empty fields")
    func sparseCardMaps() throws {
        let items = try Self.page("client_search_page").items
        try #require(items.count > 1)
        let item = ClientItem(wire: items[1])

        #expect(item.displayName == nil)
        #expect(item.segment == nil)
        #expect(item.storeCode == nil)
        #expect(item.storeName == nil)
        #expect(item.salesAssociateExternalId == nil)
        #expect(item.salesAssociateName == nil)
    }

    @Test("A card from a BFF that does not send the store yet maps, its store's name left empty")
    func cardWithoutStoreMaps() throws {
        // client_sync_page2.json is a client as the BFF served it before the card, on a route the app no longer
        // calls: no store, and fields the app does not read — decoding ignores them.
        let item = ClientItem(wire: try #require(try Self.page("client_sync_page2").items.first))

        #expect(item.storeCode == "90917634296")
        #expect(item.storeName == nil)
        #expect(item.salesAssociateName == "Elie Buff")
    }

    @Test("The salutation, language, address and consents map onto the item as sent")
    func baseDataMaps() throws {
        // Set on the decoded wire: no fixture copied from the BFF carries an address yet.
        var wire = try #require(try Self.page("client_my_clients_page").items.first)
        wire.salutation = "misses"
        wire.preferredLanguage = "fr"
        wire.mainAddress = ClientWire.Address(
            street: "12 Rue Royale", postalCode: "75008", city: "Paris", state: nil, country: "FR"
        )
        wire.optIns = ClientWire.OptIns(email: true, directMessage: false, call: true, wechat: false, line: true)

        let item = ClientItem(wire: wire)

        #expect(item.salutation == "misses")
        #expect(item.preferredLanguage == "fr")
        #expect(item.address == ClientItem.Address(
            street: "12 Rue Royale", postalCode: "75008", city: "Paris", state: nil, country: "FR"
        ))
        #expect(item.optIns == ClientItem.OptIns(email: true, directMessage: false, call: true, wechat: false, line: true))
    }

    // MARK: - Whose client

    @Test(
        "A client is assigned to the associate of the same external id; a missing id, on either side, never matches",
        arguments: [
            ("sa-1", "sa-1", true), ("sa-1", "sa-2", false), (nil, "sa-1", false), ("sa-1", nil, false), (nil, nil, false),
        ] as [(String?, String?, Bool)]
    )
    func isAssigned(clientAssociate: String?, associate: String?, expected: Bool) {
        let client = ClientItem(id: "1", salesAssociateExternalId: clientAssociate)

        #expect(client.isAssigned(to: associate) == expected)
    }

    // MARK: - Consents

    @Test("A channel reads and writes its own consent, and only it")
    func channelSubscript() {
        var optIns = ClientItem.OptIns(email: false, directMessage: false, call: false, wechat: false, line: false)

        optIns[channel: .wechat] = true

        #expect(optIns[channel: .wechat])
        #expect(optIns == ClientItem.OptIns(email: false, directMessage: false, call: false, wechat: true, line: false))
    }

    @Test("The changed channels are those whose consent differs, in their order")
    func changedChannels() {
        var edited = Self.optIns
        edited.line = true
        edited.email = false

        #expect(edited.changedChannels(from: Self.optIns) == [.email, .line])
        #expect(Self.optIns.changedChannels(from: Self.optIns).isEmpty)
    }

    // MARK: - Edit

    @Test("A space typed changes nothing; a field cleared does, and an address left with no line is none")
    func normalizedChanges() {
        let original = ClientItem(id: "1", firstName: "Alice", primaryEmail: "alice@example.com", address: Self.address)
        var spaced = original
        spaced.firstName = " Alice  "
        var cleared = original
        cleared.primaryEmail = " "
        var noAddress = original
        noAddress.address = ClientItem.Address(street: "  ", city: "")

        #expect(!spaced.hasChanges(from: original))
        #expect(cleared.hasChanges(from: original))
        #expect(cleared.normalized.primaryEmail == nil)
        #expect(noAddress.normalized.address == nil)
    }

    @Test("Clearing both names is refused; clearing one keeps the other")
    func namesStay() {
        let original = ClientItem(id: "1", firstName: "Alice", lastName: "Martinez")
        var noName = original
        noName.firstName = ""
        noName.lastName = " "
        var lastNameOnly = original
        lastNameOnly.firstName = nil

        #expect(!noName.isValid(from: original))
        #expect(lastNameOnly.isValid(from: original))
    }

    @Test(
        "A changed email is cleared or well formed, by zod's rule",
        arguments: [
            ("nina@example.com", true), ("", true), ("nina.larsen+vip@shop.co.uk", true),
            ("nina", false), ("nina@example", false), ("nina..larsen@example.com", false), (".nina@example.com", false),
        ] as [(String, Bool)]
    )
    func changedEmail(email: String, valid: Bool) {
        let original = ClientItem(id: "1", firstName: "Nina", primaryEmail: "nina.old@example.com")
        var edited = original
        edited.primaryEmail = email

        #expect(edited.isEmailValid(from: original) == valid)
        #expect(edited.isValid(from: original) == valid)
    }

    @Test("A client imported without a name, or with a broken email, can still have their phone corrected")
    func unsentFieldsAreNotJudged() {
        let original = ClientItem(id: "1", primaryEmail: "n/a", primaryPhone: "+33 6 12 34 56 78")
        var edited = original
        edited.primaryPhone = "+33 6 00 00 00 00"

        #expect(edited.isValid(from: original))
        #expect(edited.isEmailValid(from: original))
    }

    // MARK: - Display

    @Test(
        "A salutation reads as its title; one this build does not know, or none, shows nothing",
        arguments: [("mister", "Mr"), ("misses", "Mrs"), ("miss", "Miss"), ("doctor", nil), (nil, nil)] as [(String?, String?)]
    )
    func salutationLabel(salutation: String?, label: String?) {
        #expect(ClientItem(id: "1", salutation: salutation).salutationLabel == label)
    }

    @Test(
        "The name reads with its salutation before it; without one this build knows, the name alone",
        arguments: [("misses", "Mrs Alice Martinez"), ("doctor", "Alice Martinez"), (nil, "Alice Martinez")]
            as [(String?, String)]
    )
    func displayLabelWithSalutation(salutation: String?, label: String) {
        let client = ClientItem(id: "1", firstName: "Alice", lastName: "Martinez", salutation: salutation)

        #expect(client.displayLabel == label)
    }

    @Test("Without a name, the placeholder alone: no salutation before it")
    func displayLabelWithoutName() {
        #expect(ClientItem(id: "1", salutation: "misses").displayLabel == String(localized: "Unnamed client"))
    }

    @Test("Email and phone share one line; either alone when the other is missing or blank; none, no line")
    func contactLine() {
        let both = ClientItem(id: "1", primaryEmail: "alice@example.com", primaryPhone: "+33 6 12 34 56 78")
        let emailOnly = ClientItem(id: "1", primaryEmail: "alice@example.com", primaryPhone: "  ")
        let phoneOnly = ClientItem(id: "1", primaryPhone: " +33 6 12 34 56 78 ")

        #expect(both.contactLine == "alice@example.com · +33 6 12 34 56 78")
        #expect(emailOnly.contactLine == "alice@example.com")
        #expect(phoneOnly.contactLine == "+33 6 12 34 56 78")
        #expect(ClientItem(id: "1", primaryEmail: "", primaryPhone: nil).contactLine == nil)
    }

    @Test("A language reads as its name in the device's language")
    func languageName() {
        #expect(ClientItem(id: "1", preferredLanguage: "fr").languageName == Locale.current.localizedString(forLanguageCode: "fr"))
        #expect(ClientItem(id: "1").languageName == nil)
    }

    @Test("An address reads line by line, the postal code beside the city and the country named")
    func addressLines() {
        #expect(Self.address.lines == ["Rua Garrett 50", "1200-204 Lisboa", Locale.current.localizedString(forRegionCode: "PT")!])
    }

    @Test("An address leaves out what the source left empty, and keeps a country it wrote as a name")
    func addressSkipsEmptyLines() {
        let address = ClientItem.Address(street: "", postalCode: nil, city: "Lisboa", state: nil, country: "Portugal")

        #expect(address.lines == ["Lisboa", "Portugal"])
    }
}

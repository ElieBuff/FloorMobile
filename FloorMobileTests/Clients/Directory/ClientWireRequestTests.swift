//
//  ClientWireRequestTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// What an edit sends to `PATCH client/{id}` (`ClientWire.Request`): only
/// what changed — a key left out is unchanged, a `null` is cleared —, the
/// address whole, and the consents only with the client's signature.
@Suite("Client edit request")
struct ClientWireRequestTests {

    /// One of the associate's own clients, as their card serves them.
    private static let original = ClientItem(
        id: "c1", firstName: "Alice", lastName: "Martinez", salesAssociateExternalId: "sa-1",
        primaryEmail: "alice@example.com", primaryPhone: "+33 6 12 34 56 78",
        address: ClientItem.Address(street: "12 Rue Royale", postalCode: "75008", city: "Paris", state: nil, country: "FR"),
        optIns: ClientItem.OptIns(email: true, directMessage: false, call: false, wechat: false, line: false)
    )

    private static let signature = ClientSignature(
        png: Data([0x89, 0x50, 0x4E, 0x47]), signedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    /// The request as `APIClient` sends it — ISO 8601 dates, `Data` in
    /// base64 — read back as a dictionary, `NSNull` for a `null`.
    private static func encoded(_ edited: ClientItem, signature: ClientSignature? = nil) throws -> [String: Any] {
        let request = ClientWire.Request(edited: edited, original: original, signature: signature)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try JSONSerialization.jsonObject(with: try encoder.encode(request))
        return try #require(object as? [String: Any])
    }

    @Test("Nothing changed sends nothing — nor does a space typed after a name")
    func unchangedSendsNothing() throws {
        var spaced = Self.original
        spaced.firstName = "Alice "

        #expect(try Self.encoded(Self.original).isEmpty)
        #expect(try Self.encoded(spaced).isEmpty)
    }

    @Test("A changed field goes alone, trimmed")
    func changedFieldGoesAlone() throws {
        var edited = Self.original
        edited.primaryPhone = "  +33 6 00 00 00 00 "

        let body = try Self.encoded(edited)

        #expect(body.count == 1)
        #expect(body["mobile"] as? String == "+33 6 00 00 00 00")
    }

    @Test("A cleared email goes as null")
    func clearedFieldGoesAsNull() throws {
        var edited = Self.original
        edited.primaryEmail = "   "

        let body = try Self.encoded(edited)

        #expect(body.keys.sorted() == ["email"])
        #expect(body["email"] is NSNull)
    }

    @Test("A changed line sends the address whole, a cleared line as null")
    func addressGoesWhole() throws {
        var edited = Self.original
        edited.address?.city = ""
        edited.address?.postalCode = "75001"

        let address = try #require(try Self.encoded(edited)["mainAddress"] as? [String: Any])

        #expect(address.keys.sorted() == ["city", "country", "postalCode", "state", "street"])
        #expect(address["street"] as? String == "12 Rue Royale")
        #expect(address["postalCode"] as? String == "75001")
        #expect(address["city"] is NSNull)
        #expect(address["state"] is NSNull)
    }

    @Test("An address with every line cleared goes as null")
    func clearedAddressGoesAsNull() throws {
        var edited = Self.original
        edited.address = ClientItem.Address(street: " ", postalCode: "", city: nil, state: nil, country: "")

        let body = try Self.encoded(edited)

        #expect(body.keys.sorted() == ["mainAddress"])
        #expect(body["mainAddress"] is NSNull)
    }

    @Test("Changed consents go whole with the signature beside them, its image in base64 and its date in ISO 8601")
    func consentsGoWithTheSignature() throws {
        var edited = Self.original
        edited.optIns?.call = true

        let body = try Self.encoded(edited, signature: Self.signature)

        let optIns = try #require(body["optins"] as? [String: Bool])
        #expect(optIns == ["email": true, "directMessage": false, "call": true, "wechat": false, "line": false])
        let signature = try #require(body["signature"] as? [String: String])
        #expect(signature["image"] == Self.signature.png.base64EncodedString())
        #expect(signature["signedAt"] == "2023-11-14T22:13:20Z")
    }

    @Test("Unchanged consents send neither the consents nor a signature")
    func unchangedConsentsSendNoSignature() throws {
        var edited = Self.original
        edited.lastName = "Martin"

        let body = try Self.encoded(edited, signature: Self.signature)

        #expect(body.keys.sorted() == ["lastName"])
    }
}

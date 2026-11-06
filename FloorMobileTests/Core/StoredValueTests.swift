//
//  StoredValueTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// A `Codable` value kept through `coded()`, on storage held in memory.
@Suite("Stored value")
struct StoredValueTests {

    @Test("A value written reads back equal")
    func codedRoundTrip() {
        let stored: StoredValue<SalesAssociateSnapshot> = StoredValue<Data>.inMemory().coded()
        let associate = SalesAssociateSnapshot(id: "sa-1", firstName: "Elie", lastName: "Buff", preferredLanguage: "Fr")

        stored.set(associate)

        #expect(stored.get() == associate)
    }

    @Test("Writing nil removes the value")
    func codedNilRemoves() {
        let data = StoredValue<Data>.inMemory()
        let stored: StoredValue<StoreSnapshot> = data.coded()
        stored.set(StoreSnapshot(id: "s-1"))

        stored.set(nil)

        #expect(stored.get() == nil)
        #expect(data.get() == nil)
    }

    @Test("Data that no longer decodes reads as nil")
    func undecodableReadsNil() {
        let stored: StoredValue<StoreSnapshot> = StoredValue<Data>.inMemory(Data("not json".utf8)).coded()

        #expect(stored.get() == nil)
    }
}

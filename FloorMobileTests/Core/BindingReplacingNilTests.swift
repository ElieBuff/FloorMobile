//
//  BindingReplacingNilTests.swift
//  FloorMobileTests
//

import SwiftUI
import Testing
@testable import FloorMobile

/// What lets a `TextField` edit an optional field: `nil` reads as the empty
/// value, and the empty value writes `nil` back — so typing then clearing
/// leaves the field as it was.
@MainActor
@Suite("Binding replacing nil")
struct BindingReplacingNilTests {

    /// The optional the binding reads and writes.
    private final class Box<Value> {
        var value: Value?
        init(_ value: Value?) { self.value = value }
    }

    private static func binding<Value>(over box: Box<Value>) -> Binding<Value?> {
        Binding(get: { box.value }, set: { box.value = $0 })
    }

    @Test("A nil value reads as the empty value")
    func nilReadsAsEmpty() {
        let box = Box<String>(nil)

        #expect(Self.binding(over: box).replacingNil(with: "").wrappedValue == "")
    }

    @Test("Writing the empty value writes nil")
    func emptyWritesNil() {
        let box = Box("Alice")

        Self.binding(over: box).replacingNil(with: "").wrappedValue = ""

        #expect(box.value == nil)
    }

    @Test("Any other value reads and writes as it is")
    func otherValuesPassThrough() {
        let box = Box("Alice")
        let text = Self.binding(over: box).replacingNil(with: "")

        #expect(text.wrappedValue == "Alice")
        text.wrappedValue = "Alicia"
        #expect(box.value == "Alicia")
    }

    @Test("An empty address stands in for none, and becomes none again once emptied")
    func addressRoundTrip() {
        let box = Box<ClientItem.Address>(nil)
        let address = Self.binding(over: box).replacingNil(with: ClientItem.Address())

        address.wrappedValue.city = "Paris"
        #expect(box.value == ClientItem.Address(city: "Paris"))
        address.wrappedValue.city = nil
        #expect(box.value == nil)
    }
}

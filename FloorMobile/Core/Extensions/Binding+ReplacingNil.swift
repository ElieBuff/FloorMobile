//
//  Binding+ReplacingNil.swift
//  FloorMobile
//

import SwiftUI

extension Binding {
    /// The optional value as a plain one: `empty` stands in for `nil`, and
    /// writing `empty` back writes `nil`.
    ///
    /// For a control bound to an optional field: a `TextField` takes a
    /// `String`, never a `String?`. The native `Binding.init?(_:)` only
    /// unwraps a value that is there; this one also gives a field that has
    /// none something to type into — and erasing it gives the field back its
    /// `nil`, so typing then clearing leaves the value as it was.
    ///
    /// ```swift
    /// TextField("First name", text: $client.firstName.replacingNil(with: ""))
    /// ```
    func replacingNil<Wrapped: Equatable>(with empty: Wrapped) -> Binding<Wrapped> where Value == Wrapped? {
        Binding<Wrapped>(
            get: { wrappedValue ?? empty },
            set: { wrappedValue = $0 == empty ? nil : $0 }
        )
    }
}

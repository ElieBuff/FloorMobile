//
//  Array+Including.swift
//  FloorMobile
//

import Foundation

nonisolated extension Array where Element: Equatable {
    /// The list with `value` appended when it is missing.
    ///
    /// For picker options: a `Picker` bound to a value its options do not
    /// contain draws an empty row, and the first tap rewrites the field
    /// silently. Widening the list is the honest answer — an appointment
    /// booked elsewhere keeps its 45 minutes until someone changes them.
    func including(_ value: Element) -> [Element] {
        contains(value) ? self : self + [value]
    }
}

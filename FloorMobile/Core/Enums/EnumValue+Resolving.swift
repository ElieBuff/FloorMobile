//
//  FieldOption+Resolving.swift
//  FloorMobile
//

import Foundation

nonisolated extension Collection where Element == FieldOption {

    /// The server's vocabulary as a list of the local enum — what a picker
    /// offers.
    ///
    /// This is the join between the two halves of an open set. The server owns
    /// **which** values exist and in what order; the app owns what each one
    /// looks like (`Reason+Presentation`). A value the server sends and this
    /// build has never heard of is dropped rather than shown: there is no
    /// label for it and no icon, so offering it would put a blank row in the
    /// list. It still decodes on records that carry it — `init(raw:)` maps it
    /// to `.other` — it simply cannot be *chosen* until a release knows it.
    ///
    /// `fallback` covers the store being empty: a preview with a bare
    /// container, or a vocabulary cached before the server grew this field.
    /// Without it the picker would open on nothing, which reads as a bug
    /// rather than as missing data.
    ///
    /// ```swift
    /// @Query(FieldOption.descriptor(for: .eventMeetingType)) private var meetingTypeOptions: [FieldOption]
    /// // …
    /// meetingTypeOptions.resolved(fallback: MeetingType.selectable)
    /// ```
    func resolved<Option>(fallback: [Option]) -> [Option]
    where Option: RawRepresentable, Option.RawValue == String {
        let known = compactMap { Option(rawValue: $0.value) }
        return known.isEmpty ? fallback : known
    }
}

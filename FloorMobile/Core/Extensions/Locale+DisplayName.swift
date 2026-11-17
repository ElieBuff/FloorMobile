//
//  Locale+DisplayName.swift
//  FloorMobile
//

import Foundation

nonisolated extension Locale {
    /// The language and its region in `reader`'s language — "French (France)"
    /// for `fr_FR` read in English —, or the identifier itself when the system
    /// does not name it: what VoiceOver says of a language downloading.
    func displayName(in reader: Locale = .current) -> String {
        reader.localizedString(forIdentifier: identifier) ?? identifier
    }

    /// The language alone in `reader`'s language — "French" for `fr_FR` or
    /// `fr` —, or the identifier itself when the system does not name it.
    func languageName(in reader: Locale = .current) -> String {
        guard let code = language.languageCode?.identifier else { return identifier }
        return reader.localizedString(forLanguageCode: code) ?? identifier
    }
}

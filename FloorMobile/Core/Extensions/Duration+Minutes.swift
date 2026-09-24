//
//  Duration+Minutes.swift
//  FloorMobile
//

import Foundation

nonisolated extension Duration {
    /// A count of minutes — the unit the API measures both an appointment's
    /// length and a reminder's lead time in.
    ///
    /// `Duration` ships `.seconds` and everything below it, so the ×60 has to
    /// live somewhere; here it lives once.
    static func minutes(_ count: Int) -> Duration {
        .seconds(count * 60)
    }

    /// "30 min", "1 h", "1 h 30 min" in French; "30 min", "1 hr", "1 hr 30 min"
    /// in English.
    ///
    /// The units, their order and their abbreviation come from the locale, so
    /// there is no format string of ours for a translator to get wrong — and a
    /// unit that would read as zero drops itself rather than printing "1 h
    /// 0 min".
    var hoursAndMinutes: String {
        formatted(.units(allowed: [.hours, .minutes], width: .condensedAbbreviated))
    }
}

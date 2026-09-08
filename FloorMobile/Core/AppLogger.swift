//
//  AppLogger.swift
//  FloorMobile
//

import Foundation
import os

/// Preconfigured loggers, one per domain. Usage: `AppLog.auth.info("Sign-in started")`.
///
/// Any user data (names, emails, identifiers, URLs containing them) must be
/// logged with `privacy: .private`. Tokens, passwords and auth response bodies
/// are never logged at all, at any level.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "FloorMobile"

    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let sync = Logger(subsystem: subsystem, category: "sync")
}

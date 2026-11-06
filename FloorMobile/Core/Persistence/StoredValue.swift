//
//  StoredValue.swift
//  FloorMobile
//

import Foundation
import Synchronization

/// One small value kept between launches — a marker, a cursor — as opposed to
/// the data itself, which lives in SwiftData.
///
/// Closures rather than `UserDefaults` directly, so a test or a preview swaps
/// in memory and never touches the device's real defaults.
nonisolated struct StoredValue<Value: Sendable>: Sendable {
    var get: @Sendable () -> Value?
    /// `nil` removes it.
    var set: @Sendable (Value?) -> Void
}

nonisolated extension StoredValue {
    /// Backed by `UserDefaults.standard`, under `key`. `Value` must be a
    /// property-list type (`String`, `Int`, `Bool`, `Date`, `Data`…).
    static func userDefaults(_ key: StoredKey) -> StoredValue {
        StoredValue(
            get: { UserDefaults.standard.object(forKey: key.rawValue) as? Value },
            set: { newValue in
                if let newValue {
                    UserDefaults.standard.set(newValue, forKey: key.rawValue)
                } else {
                    UserDefaults.standard.removeObject(forKey: key.rawValue)
                }
            }
        )
    }

    /// Held in memory, for tests and previews.
    static func inMemory(_ initial: Value? = nil) -> StoredValue {
        let box = Box(initial)
        return StoredValue(
            get: { box.value.withLock { $0 } },
            set: { newValue in box.value.withLock { $0 = newValue } }
        )
    }

    /// A `Mutex` cannot be copied, so the closures share it through a class.
    private final class Box: Sendable {
        let value: Mutex<Value?>
        init(_ initial: Value?) { value = Mutex(initial) }
    }
}

nonisolated extension StoredValue where Value == Data {
    /// The same storage holding a `Codable` value, as JSON — for a value that
    /// is not a property-list type (`SalesAssociateSnapshot`). A transformation
    /// rather than a `.userDefaults` variant, so a test runs it on
    /// `.inMemory()`.
    ///
    /// A value that no longer decodes — its shape changed with an update —
    /// reads as `nil`: what the server sends next writes it again.
    func coded<Coded: Codable & Sendable>() -> StoredValue<Coded> {
        StoredValue<Coded>(
            get: { get().flatMap { try? JSONDecoder().decode(Coded.self, from: $0) } },
            set: { newValue in set(newValue.flatMap { try? JSONEncoder().encode($0) }) }
        )
    }
}

nonisolated extension StoredValue where Value == SalesAssociateSnapshot {
    /// The associate signed in, which `AppSession` keeps (`keep`) and the
    /// dictation reads the language of (`TranscriptionLanguage.live`).
    static var signedInAssociate: StoredValue {
        StoredValue<Data>.userDefaults(.signedInAssociate).coded()
    }
}

nonisolated extension StoredValue where Value == StoreSnapshot {
    /// The store of the associate signed in, which `AppSession` keeps.
    static var signedInStore: StoredValue {
        StoredValue<Data>.userDefaults(.signedInStore).coded()
    }
}

/// Every key the app keeps in `UserDefaults`, in one place: no two values can
/// collide on a name, and the full list reads at a glance.
nonisolated enum StoredKey: String, Sendable {
    /// The tenant the local store holds — see `LocalStore`.
    case lastTenantID
    /// Where the store's client sync resumes from — see `ClientService`.
    case clientSyncCursor
    /// The associate signed in, as `GET setup` last described them — their
    /// language included — kept by `AppSession` for a launch offline.
    case signedInAssociate
    /// The store of the associate signed in, beside them.
    case signedInStore
    /// The language last picked in the transcription sheet — a preference of
    /// the device, kept across sign-outs. See `TranscriptionLanguage`.
    case transcriptionLanguage
}

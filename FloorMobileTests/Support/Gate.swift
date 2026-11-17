//
//  Gate.swift
//  FloorMobileTests
//

import Foundation

/// Holds a fake call where a test wants it — an iOS download that has not
/// finished yet: the fake waits at the gate (`wait()`) until the test opens it
/// (`open()`), and the test waits until the fake got there (`reached()`).
/// Task cancellation does not open it, as iOS may not stop for it either.
@MainActor
final class Gate {
    private var isWaiting = false
    private var opening: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?

    /// Called by the fake: waits until the test opens the gate.
    func wait() async {
        isWaiting = true
        arrival?.resume()
        arrival = nil
        await withCheckedContinuation { opening = $0 }
    }

    /// Called by the test: returns once the fake waits at the gate.
    func reached() async {
        guard !isWaiting else { return }
        await withCheckedContinuation { arrival = $0 }
    }

    /// Lets the fake go on.
    func open() {
        opening?.resume()
        opening = nil
    }
}

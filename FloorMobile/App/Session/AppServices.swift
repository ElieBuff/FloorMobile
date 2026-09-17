//
//  AppServices.swift
//  FloorMobile
//

import Foundation
import Observation
import SwiftData

/// The app's data services, built once at the composition root from the shared
/// `ModelContainer` and injected down the view tree by type (like `AppSession`).
/// Each service is a `@ModelActor`, so it owns a private context on its own
/// off-main executor. A missing injection surfaces as SwiftUI's standard
/// "no Observable object of type" runtime error — no throwaway container.
@Observable
final class AppServices {
    let aiActions: AIActionService
    let agenda: AgendaService

    init(container: ModelContainer) {
        aiActions = AIActionService(modelContainer: container)
        agenda = AgendaService(modelContainer: container)
    }
}

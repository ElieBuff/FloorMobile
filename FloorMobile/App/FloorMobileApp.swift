//
//  FloorMobileApp.swift
//  FloorMobile
//
//  Created by elie buff on 07/09/2026.
//

import SwiftUI
import SwiftData
import os

@main
struct FloorMobileApp: App {
    let sharedModelContainer: ModelContainer
    private let services: AppServices
    /// Built before everything: the API client is handed it at birth, and
    /// `RootView` acts on it.
    private let sessionExpiry = SessionExpiry()

    /// Production wiring: environment-driven configuration, Keychain-backed
    /// tokens, real login window.
    @State private var session: AppSession

    /// Builds the container first so `session` and `services` can share the one
    /// instance — stored-property initializers can't reference each other.
    init() {
        let container = Self.makeModelContainer()
        #if DEBUG
        AppLog.sync.log("DB Log URL: \(container.configurations.first?.url.absoluteString ?? "unknown", privacy: .public)")
        #endif
        let authManager = AuthManager(
            configuration: Self.makeConfiguration(),
            store: KeychainTokenStore(),
            webAuthenticator: WebAuthenticator()
        )
        let apiClient = Self.makeAPIClient(authManager: authManager, expiry: sessionExpiry)

        sharedModelContainer = container
        services = AppServices(container: container)
        _session = State(initialValue: AppSession(auth: .live(authManager), api: apiClient))
    }

    /// Builds the shared SwiftData container from the versioned schema.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: FloorSchemaV1.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: FloorMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// A missing configuration must be visible: refusing to launch with a
    /// clear message beats running against the wrong environment.
    private static func makeConfiguration() -> AuthConfiguration {
        do {
            return try AuthConfiguration.fromBundle()
        } catch {
            fatalError("""
                Auth configuration is missing from Info.plist. Assign the \
                Config/*.xcconfig files to the build configurations \
                (project → Info → Configurations). \(error)
                """)
        }
    }
    
    /// Creates the API client with the base URL from the active xcconfig.
    private static func makeAPIClient(authManager: AuthManager, expiry: SessionExpiry) -> APIClient {
        do {
            let apiConfig = try APIConfiguration.fromBundle()
            return APIClient(
                baseURL: apiConfig.baseURL,
                tokens: TokenProviding.live(authManager),
                expiry: expiry
            )
        } catch {
            fatalError("""
                API configuration is missing from Info.plist. Assign the \
                Config/*.xcconfig files to the build configurations. \(error)
                """)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Ink, not the system blue. With no accent defined, SwiftUI
                // hands every control its default — and that blue was the only
                // saturated colour on the agenda's forms, pulling the eye to
                // Duration and Reminder while the empty, required Client row
                // stayed the palest thing on screen. Colour was inverting the
                // hierarchy, and it came from nowhere in the design system.
                .tint(Color(.Base.ink))
                // Light only, deliberately, until the tokens have dark variants.
                // They are all light today — ink on white surfaces over a light
                // backdrop image — but system controls still follow the device,
                // so in dark mode the placeholders all but vanish and the date
                // capsules go white-on-pale. A light-only app beats a half-dark
                // one; this line comes out the day the colorsets gain their
                // dark appearances.
                .preferredColorScheme(.light)
                .task {
                    #if DEBUG
                    // UI tests launch with --wipe-session to start signed out.
                    if CommandLine.arguments.contains("--wipe-session") {
                        try? await KeychainTokenStore().clear()
                    }
                    #endif
                    await session.start()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(session)
        .environment(services)
        .environment(sessionExpiry)
    }
}

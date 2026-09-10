//
//  FloorMobileApp.swift
//  FloorMobile
//
//  Created by elie buff on 07/09/2026.
//

import SwiftUI
import SwiftData

@main
struct FloorMobileApp: App {
    var sharedModelContainer: ModelContainer = {
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
    }()

    /// Production wiring: environment-driven configuration, Keychain-backed
    /// tokens, real login window.
    @State private var session = AppSession(
        auth: .live(AuthManager(
            configuration: Self.makeConfiguration(),
            store: KeychainTokenStore(),
            webAuthenticator: WebAuthenticator()
        ))
    )

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

    var body: some Scene {
        WindowGroup {
            RootView()
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
    }
}

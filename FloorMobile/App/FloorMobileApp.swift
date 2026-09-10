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
    @State private var session: AppSession = {
        let authManager = AuthManager(
            configuration: Self.makeConfiguration(),
            store: KeychainTokenStore(),
            webAuthenticator: WebAuthenticator()
        )
        
        let apiClient = Self.makeAPIClient(authManager: authManager)
        
        return AppSession(
            auth: .live(authManager),
            api: apiClient
        )
    }()

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
    private static func makeAPIClient(authManager: AuthManager) -> APIClient {
        do {
            let apiConfig = try APIConfiguration.fromBundle()
            return APIClient(
                baseURL: apiConfig.baseURL,
                tokens: TokenProviding.live(authManager)
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

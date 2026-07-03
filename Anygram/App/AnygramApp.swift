import SwiftUI

@main
struct AnygramApp: App {
    @StateObject private var container = DIContainer.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if container.isAuthenticated {
                    MainTabView(container: container)
                } else {
                    AuthFlowView(container: container)
                }
            }
            .environmentObject(container)
            .animation(AppAnimation.standard, value: container.isAuthenticated)
            .task {
                AppDebugLogger.shared.log("App launch", category: .UI)
                await container.bootstrap()
                #if canImport(TDLibKit)
                #if !USE_SCAFFOLD_AUTH
                if !AuthBuildConfiguration.usesScaffoldAuth {
                    AppDebugLogger.shared.log("DI pre-warm: authRepository.bootstrap()", category: .AUTH)
                    try? await container.authRepository.bootstrap()
                }
                #endif
                #endif
            }
        }
    }
}

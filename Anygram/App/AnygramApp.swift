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
                await container.bootstrap()
            }
        }
    }
}

import SwiftUI

@main
struct AnygramApp: App {
    @StateObject private var container = DIContainer.shared

    var body: some Scene {
        WindowGroup {
            MainTabView(container: container)
                .environmentObject(container)
                .task {
                    await container.bootstrap()
                }
        }
    }
}

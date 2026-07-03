import Foundation

/// Compile-time auth backend selection mirrored across services and UI.
enum AuthBuildConfiguration {
    static var usesScaffoldAuth: Bool {
        #if USE_SCAFFOLD_AUTH
        return true
        #elseif targetEnvironment(simulator)
        return true
        #elseif canImport(TDLibKit)
        return false
        #else
        return true
        #endif
    }

    static var buildLabel: String {
        usesScaffoldAuth ? "scaffold" : "tdlib"
    }
}

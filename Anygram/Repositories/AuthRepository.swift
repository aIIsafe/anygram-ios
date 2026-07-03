import Combine
import Foundation

/// Repository coordinating Telegram authentication through the service layer.
public final class AuthRepository: @unchecked Sendable {
    private let authService: AuthServiceProtocol
    private let networkService: TelegramNetworkService

    public init(authService: AuthServiceProtocol, networkService: TelegramNetworkService) {
        self.authService = authService
        self.networkService = networkService
    }

    public var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    public var usesScaffoldAuth: Bool {
        authService.usesScaffoldAuth
    }

    public var authorizationState: AuthAuthorizationState {
        authService.authorizationState
    }

    public var authorizationStatePublisher: AnyPublisher<AuthAuthorizationState, Never> {
        authService.authorizationStatePublisher
    }

    public func bootstrap() async throws {
        AppDebugLogger.shared.log("AuthRepository.bootstrap", category: .AUTH)
        try await networkService.bootstrapForLogin()
    }

    public func submitPhoneNumber(_ phoneNumber: String) async throws {
        AppDebugLogger.shared.log("AuthRepository.submitPhoneNumber", category: .AUTH)
        do {
            try await networkService.bootstrapForLogin()
            try await authService.setPhoneNumber(phoneNumber)
        } catch {
            AppDebugLogger.shared.log("AuthRepository.submitPhoneNumber failed: \(error.localizedDescription)", category: .ERROR)
            if shouldResetSession(after: error) {
                networkService.resetLoginBootstrap()
            }
            throw error
        }
    }

    private func shouldResetSession(after error: Error) -> Bool {
        if case AuthError.stillStarting = error { return true }
        if case AuthError.networkUnavailable = error { return true }
        if case AuthError.tdlibError(let message) = error, message.contains("TIMEOUT") { return true }
        return false
    }

    public func submitCode(_ code: String) async throws {
        try await authService.checkAuthenticationCode(code)
    }

    public func submitPassword(_ password: String) async throws {
        try await authService.checkAuthenticationPassword(password)
    }

    public func resendCode() async throws {
        try await authService.resendAuthenticationCode()
    }

    public func logout() async throws {
        try await authService.logout()
    }

    public func fetchCurrentUser() async throws -> User? {
        try await authService.fetchCurrentUser()
    }
}

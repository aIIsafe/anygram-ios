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

    public var authorizationState: AuthAuthorizationState {
        authService.authorizationState
    }

    public var authorizationStatePublisher: AnyPublisher<AuthAuthorizationState, Never> {
        authService.authorizationStatePublisher
    }

    public func bootstrap() async throws {
        try await networkService.bootstrapForLogin()
    }

    public func submitPhoneNumber(_ phoneNumber: String) async throws {
        try await authService.setPhoneNumber(phoneNumber)
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
}

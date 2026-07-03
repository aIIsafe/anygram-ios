import Combine
import Foundation

/// TDLib authorization state mirrored for UI routing.
public enum AuthAuthorizationState: Equatable, Sendable {
    case unknown
    case waitPhoneNumber
    case waitCode(codeLength: Int, resendTimeout: Int)
    case waitPassword(hint: String?)
    case waitRegistration
    case ready
    case closed
}

/// Auth operation errors surfaced to the UI layer.
public enum AuthError: Error, LocalizedError, Equatable, Sendable {
    case notConfigured
    case invalidPhoneNumber
    case invalidCode
    case invalidPassword
    case networkUnavailable
    case tdlibError(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L10n.authGenericError
        case .invalidPhoneNumber:
            return L10n.authInvalidPhone
        case .invalidCode:
            return L10n.authInvalidCode
        case .invalidPassword:
            return L10n.authInvalidPassword
        case .networkUnavailable:
            return L10n.authGenericError
        case .tdlibError(let message):
            return message
        case .unknown:
            return L10n.authGenericError
        }
    }
}

/// Clean-architecture auth boundary. Real implementation uses TDLib when available.
public protocol AuthServiceProtocol: Sendable {
    var authorizationState: AuthAuthorizationState { get }
    var authorizationStatePublisher: AnyPublisher<AuthAuthorizationState, Never> { get }
    var isAuthenticated: Bool { get }

    func initialize() async throws
    func setPhoneNumber(_ phoneNumber: String) async throws
    func checkAuthenticationCode(_ code: String) async throws
    func checkAuthenticationPassword(_ password: String) async throws
    func resendAuthenticationCode() async throws
    func logout() async throws
}

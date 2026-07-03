import Combine
import Foundation

/// TDLib-backed auth service with compile-time stub for CI builds without TDLibKit.
public final class TDLibAuthService: AuthServiceProtocol, @unchecked Sendable {
    private let backend: AuthBackend
    private let stateSubject: CurrentValueSubject<AuthAuthorizationState, Never>

    public var authorizationState: AuthAuthorizationState {
        stateSubject.value
    }

    public var authorizationStatePublisher: AnyPublisher<AuthAuthorizationState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var isAuthenticated: Bool {
        if case .ready = authorizationState { return true }
        return false
    }

    public init() {
        #if canImport(TDLibKit)
        let backend = TDLibAuthBackend()
        #else
        let backend = ScaffoldAuthBackend()
        #endif
        self.backend = backend
        self.stateSubject = CurrentValueSubject(backend.currentState)
        backend.onStateChange = { [weak stateSubject] state in
            stateSubject?.send(state)
        }
    }

    public func initialize() async throws {
        try await backend.initialize()
        stateSubject.send(backend.currentState)
    }

    public func setPhoneNumber(_ phoneNumber: String) async throws {
        try await backend.setPhoneNumber(phoneNumber)
        stateSubject.send(backend.currentState)
    }

    public func checkAuthenticationCode(_ code: String) async throws {
        try await backend.checkAuthenticationCode(code)
        stateSubject.send(backend.currentState)
    }

    public func checkAuthenticationPassword(_ password: String) async throws {
        try await backend.checkAuthenticationPassword(password)
        stateSubject.send(backend.currentState)
    }

    public func resendAuthenticationCode() async throws {
        try await backend.resendAuthenticationCode()
        stateSubject.send(backend.currentState)
    }

    public func logout() async throws {
        try await backend.logout()
        stateSubject.send(backend.currentState)
    }
}

// MARK: - Backend protocol

private protocol AuthBackend: Sendable {
    var currentState: AuthAuthorizationState { get }
    var onStateChange: (@Sendable (AuthAuthorizationState) -> Void)? { get set }

    func initialize() async throws
    func setPhoneNumber(_ phoneNumber: String) async throws
    func checkAuthenticationCode(_ code: String) async throws
    func checkAuthenticationPassword(_ password: String) async throws
    func resendAuthenticationCode() async throws
    func logout() async throws
}

// MARK: - Scaffold backend (no TDLib binary)

private final class ScaffoldAuthBackend: AuthBackend, @unchecked Sendable {
    var onStateChange: (@Sendable (AuthAuthorizationState) -> Void)?
    private(set) var currentState: AuthAuthorizationState = .waitPhoneNumber
    private var pendingPhone: String?
    private var requiresTwoFactor = false

    func initialize() async throws {
        currentState = .waitPhoneNumber
        onStateChange?(currentState)
    }

    func setPhoneNumber(_ phoneNumber: String) async throws {
        let digits = phoneNumber.filter(\.isNumber)
        guard digits.count >= 10 else { throw AuthError.invalidPhoneNumber }
        pendingPhone = phoneNumber
        try await Task.sleep(nanoseconds: 600_000_000)
        currentState = .waitCode(codeLength: 5, resendTimeout: 60)
        onStateChange?(currentState)
    }

    func checkAuthenticationCode(_ code: String) async throws {
        let digits = code.filter(\.isNumber)
        guard digits.count >= 5 else { throw AuthError.invalidCode }
        try await Task.sleep(nanoseconds: 500_000_000)
        if requiresTwoFactor || pendingPhone?.hasSuffix("42") == true {
            currentState = .waitPassword(hint: nil)
        } else {
            currentState = .ready
        }
        onStateChange?(currentState)
    }

    func checkAuthenticationPassword(_ password: String) async throws {
        guard !password.isEmpty else { throw AuthError.invalidPassword }
        try await Task.sleep(nanoseconds: 400_000_000)
        currentState = .ready
        onStateChange?(currentState)
    }

    func resendAuthenticationCode() async throws {
        guard case .waitCode = currentState else { return }
        currentState = .waitCode(codeLength: 5, resendTimeout: 60)
        onStateChange?(currentState)
    }

    func logout() async throws {
        pendingPhone = nil
        requiresTwoFactor = false
        currentState = .waitPhoneNumber
        onStateChange?(currentState)
    }
}

#if canImport(TDLibKit)
import TDLibKit

private final class TDLibAuthBackend: AuthBackend, @unchecked Sendable {
    var onStateChange: (@Sendable (AuthAuthorizationState) -> Void)?
    private(set) var currentState: AuthAuthorizationState = .unknown
    private var manager: TDLibClientManager?
    private var client: TDLibClient?
    private var parametersApplied = false

    func initialize() async throws {
        guard TelegramAPIConfiguration.isConfigured else {
            throw AuthError.notConfigured
        }
        if manager == nil {
            manager = TDLibClientManager()
        }
        guard let manager else { throw AuthError.notConfigured }
        if client == nil {
            client = manager.createClient { [weak self] data, tdClient in
                self?.handleUpdate(data: data, client: tdClient)
            }
        }
        try await applyTdlibParameters()
        try await applyProxyIfNeeded()
    }

    func setPhoneNumber(_ phoneNumber: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        _ = try await client.setAuthenticationPhoneNumber(
            phoneNumber: phoneNumber,
            settings: nil
        )
    }

    func checkAuthenticationCode(_ code: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        _ = try await client.checkAuthenticationCode(code: code)
    }

    func checkAuthenticationPassword(_ password: String) async throws {
        guard let client else { throw AuthError.notConfigured }
        _ = try await client.checkAuthenticationPassword(password: password)
    }

    func resendAuthenticationCode() async throws {
        guard let client else { throw AuthError.notConfigured }
        _ = try await client.resendAuthenticationCode()
    }

    func logout() async throws {
        guard let client else {
            currentState = .waitPhoneNumber
            onStateChange?(currentState)
            return
        }
        _ = try await client.logOut()
        currentState = .waitPhoneNumber
        onStateChange?(currentState)
    }

    private func applyTdlibParameters() async throws {
        guard let client, !parametersApplied else { return }
        let params = TdlibParameters(
            apiId: TelegramAPIConfiguration.apiId,
            apiHash: TelegramAPIConfiguration.apiHash,
            systemLanguageCode: TelegramAPIConfiguration.systemLanguageCode,
            deviceModel: TelegramAPIConfiguration.deviceModel,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            applicationVersion: TelegramAPIConfiguration.applicationVersion,
            useMessageDatabase: true,
            useSecretChats: false,
            databaseDirectory: TelegramAPIConfiguration.databaseDirectory,
            filesDirectory: TelegramAPIConfiguration.filesDirectory,
            useFileDatabase: true,
            useChatInfoDatabase: true,
            useTestDc: false
        )
        _ = try await client.setTdlibParameters(parameters: params)
        parametersApplied = true
    }

    private func applyProxyIfNeeded() async {
        let proxy = await TDLibProxyBridge.shared.activeProxy
        guard let proxy, let client else { return }
        let secretData = Data(base64Encoded: proxy.secret) ?? Data(proxy.secret.utf8)
        _ = try? await client.addProxy(
            server: proxy.server,
            port: proxy.port,
            enable: true,
            type: .proxyTypeMtproto(secret: secretData)
        )
    }

    private func handleUpdate(data: Data, client: TDLibClient) {
        guard let update = try? client.decoder.decode(Update.self, from: data) else { return }
        if case .updateAuthorizationState(let authUpdate) = update {
            mapAuthorizationState(authUpdate.authorizationState)
        }
    }

    private func mapAuthorizationState(_ state: AuthorizationState) {
        switch state {
        case .authorizationStateWaitPhoneNumber:
            currentState = .waitPhoneNumber
        case .authorizationStateWaitCode(let info):
            currentState = .waitCode(
                codeLength: Int(info.codeInfo.type.length),
                resendTimeout: Int(info.codeInfo.timeout)
            )
        case .authorizationStateWaitPassword(let info):
            currentState = .waitPassword(hint: info.passwordHint)
        case .authorizationStateWaitRegistration:
            currentState = .waitRegistration
        case .authorizationStateReady:
            currentState = .ready
        case .authorizationStateClosed:
            currentState = .closed
        default:
            break
        }
        onStateChange?(currentState)
    }
}
#endif

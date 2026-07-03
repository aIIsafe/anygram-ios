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
        let pair = Self.makeBackendPair()
        self.backend = pair.backend
        self.stateSubject = pair.subject
    }

    private static func makeBackendPair() -> (
        backend: AuthBackend,
        subject: CurrentValueSubject<AuthAuthorizationState, Never>
    ) {
        #if USE_SCAFFOLD_AUTH
        let impl = ScaffoldAuthBackend()
        #elseif targetEnvironment(simulator)
        let impl = ScaffoldAuthBackend()
        #elseif canImport(TDLibKit)
        let impl = TDLibAuthBackend()
        #else
        let impl = ScaffoldAuthBackend()
        #endif
        let subject = CurrentValueSubject<AuthAuthorizationState, Never>(impl.currentState)
        impl.onStateChange = { subject.send($0) }
        return (impl, subject)
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

    public func fetchCurrentUser() async throws -> User? {
        try await backend.fetchCurrentUser()
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
    func fetchCurrentUser() async throws -> User?
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

    func fetchCurrentUser() async throws -> User? {
        guard case .ready = currentState else { return nil }
        return User(
            id: MockDataGenerator.currentUserID,
            name: "Anygram User",
            username: "anygram_user",
            avatarColorHex: "#4ECDC4",
            phone: pendingPhone ?? "+7 000 000 00 00",
            bio: "Scaffold mode",
            isOnline: true
        )
    }
}

#if canImport(TDLibKit)
import TDLibKit

private final class TDLibAuthBackend: AuthBackend, @unchecked Sendable {
    var onStateChange: (@Sendable (AuthAuthorizationState) -> Void)?
    private(set) var currentState: AuthAuthorizationState = .unknown
    private var parametersApplied = false
    private var cachedUser: User?
    private let stateLock = NSLock()

    func initialize() async throws {
        guard TelegramAPIConfiguration.isConfigured else {
            throw AuthError.notConfigured
        }
        _ = TDLibSession.shared.ensureClient { [weak self] data, client in
            self?.handleUpdate(data: data, client: client)
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        stateLock.lock()
        let state = currentState
        stateLock.unlock()
        if case .unknown = state {
            currentState = .waitPhoneNumber
            onStateChange?(currentState)
        }
    }

    func setPhoneNumber(_ phoneNumber: String) async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        let digits = phoneNumber.filter(\.isNumber)
        guard digits.count >= 10 else { throw AuthError.invalidPhoneNumber }
        do {
            _ = try await client.setAuthenticationPhoneNumber(
                phoneNumber: phoneNumber,
                settings: nil
            )
        } catch {
            throw mapTDLibError(error)
        }
    }

    func checkAuthenticationCode(_ code: String) async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        let digits = code.filter(\.isNumber)
        guard !digits.isEmpty else { throw AuthError.invalidCode }
        do {
            _ = try await client.checkAuthenticationCode(code: code)
        } catch {
            throw mapTDLibError(error, invalidCode: true, invalidPassword: false)
        }
    }

    func checkAuthenticationPassword(_ password: String) async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        guard !password.isEmpty else { throw AuthError.invalidPassword }
        do {
            _ = try await client.checkAuthenticationPassword(password: password)
        } catch {
            throw mapTDLibError(error, invalidCode: false, invalidPassword: true)
        }
    }

    func resendAuthenticationCode() async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        _ = try await client.resendAuthenticationCode()
    }

    func logout() async throws {
        cachedUser = nil
        if let client = TDLibSession.shared.tdClient {
            _ = try await client.logOut()
        }
        currentState = .waitPhoneNumber
        onStateChange?(currentState)
    }

    func fetchCurrentUser() async throws -> User? {
        if let cachedUser { return cachedUser }
        guard let client = TDLibSession.shared.tdClient else { return nil }
        let tdUser = try await client.getMe()
        let user = Self.mapTDLibUser(tdUser)
        cachedUser = user
        return user
    }

    private func handleUpdate(data: Data, client: TDLibClient) {
        guard let update = try? client.decoder.decode(Update.self, from: data) else { return }
        if case .updateAuthorizationState(let authUpdate) = update {
            Task { await processAuthorizationState(authUpdate.authorizationState) }
        }
    }

    private func processAuthorizationState(_ state: AuthorizationState) async {
        switch state {
        case .authorizationStateWaitTdlibParameters:
            await applyTdlibParameters()
        case .authorizationStateWaitPhoneNumber:
            currentState = .waitPhoneNumber
            onStateChange?(currentState)
        case .authorizationStateWaitCode(let info):
            currentState = .waitCode(
                codeLength: max(Int(info.codeInfo.type.length), 5),
                resendTimeout: max(Int(info.codeInfo.timeout), 0)
            )
            onStateChange?(currentState)
        case .authorizationStateWaitPassword(let info):
            currentState = .waitPassword(hint: info.passwordHint)
            onStateChange?(currentState)
        case .authorizationStateWaitRegistration:
            currentState = .waitRegistration
            onStateChange?(currentState)
        case .authorizationStateReady:
            currentState = .ready
            onStateChange?(currentState)
            cachedUser = try? await fetchCurrentUser()
        case .authorizationStateClosed:
            currentState = .closed
            cachedUser = nil
            onStateChange?(currentState)
        case .authorizationStateLoggingOut:
            currentState = .waitPhoneNumber
            cachedUser = nil
            onStateChange?(currentState)
        default:
            break
        }
    }

    private func applyTdlibParameters() async {
        guard let client = TDLibSession.shared.tdClient, !parametersApplied else { return }
        do {
            let params = TdlibParameters(
                apiId: TelegramAPIConfiguration.apiId,
                apiHash: TelegramAPIConfiguration.apiHash,
                systemLanguageCode: TelegramAPIConfiguration.systemLanguageCode,
                deviceModel: TelegramAPIConfiguration.deviceModel,
                systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                applicationVersion: TelegramAPIConfiguration.applicationVersion,
                useMessageDatabase: true,
                useSecretChats: false,
                databaseDirectory: TelegramAPIConfiguration.databaseDirectoryPath,
                filesDirectory: TelegramAPIConfiguration.filesDirectoryPath,
                useFileDatabase: true,
                useChatInfoDatabase: true,
                useTestDc: false
            )
            _ = try await client.setTdlibParameters(parameters: params)
            parametersApplied = true
            if let client = TDLibSession.shared.tdClient {
                await TDLibProxyApplier.applyForcedProxy(client: client)
            }
        } catch {
            currentState = .closed
            onStateChange?(currentState)
        }
    }

    private func mapTDLibError(
        _ error: Error,
        invalidCode: Bool = false,
        invalidPassword: Bool = false
    ) -> AuthError {
        let message = error.localizedDescription.lowercased()
        if invalidCode, message.contains("phone") || message.contains("code") || message.contains("400") {
            return .invalidCode
        }
        if invalidPassword, message.contains("password") || message.contains("400") {
            return .invalidPassword
        }
        return .tdlibError(error.localizedDescription)
    }

    private static func mapTDLibUser(_ tdUser: TDLibKit.User) -> User {
        let firstName = tdUser.firstName
        let lastName = tdUser.lastName
        let displayName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        let username = tdUser.usernames?.editableUsername
            ?? tdUser.usernames?.activeUsernames.first
            ?? ""
        let isOnline: Bool
        if case .userStatusOnline = tdUser.status {
            isOnline = true
        } else {
            isOnline = false
        }

        return User(
            id: TelegramIdentity.uuid(fromTelegramId: tdUser.id),
            name: displayName.isEmpty ? firstName : displayName,
            username: username,
            avatarColorHex: TelegramIdentity.colorHex(forTelegramId: tdUser.id),
            phone: tdUser.phoneNumber,
            bio: "",
            status: "",
            isOnline: isOnline,
            isPremium: tdUser.isPremium,
            isVerified: tdUser.isVerified
        )
    }
}
#endif

import Combine
import Foundation
import os

/// TDLib-backed auth service with compile-time stub for CI builds without TDLibKit.
public final class TDLibAuthService: AuthServiceProtocol, @unchecked Sendable {
    private let backend: AuthBackend
    private let stateSubject: CurrentValueSubject<AuthAuthorizationState, Never>

    public var usesScaffoldAuth: Bool { AuthBuildConfiguration.usesScaffoldAuth }

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
        print("[AnygramAuth] Scaffold mode: simulating SMS for \(phoneNumber) — no real Telegram code is sent")
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

private let authLogger = Logger(subsystem: "com.anygram.app", category: "TDLibAuth")

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
        try await TDLibSession.shared.awaitBootstrap(timeout: 10)

        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        try await TDLibProxyApplier.applyForcedProxy(client: client)

        AuthConnectionStatus.post(.waitingTdlib)
        try await waitForPhoneNumberState(timeout: 30)
        AuthConnectionStatus.post(.idle)
    }

    func setPhoneNumber(_ phoneNumber: String) async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        let normalized = Self.normalizePhoneNumber(phoneNumber)
        let digits = normalized.filter(\.isNumber)
        guard digits.count >= 10 else { throw AuthError.invalidPhoneNumber }

        try await TDLibProxyApplier.applyForcedProxy(client: client)
        AuthConnectionStatus.post(.waitingTdlib)
        try await waitForPhoneNumberState(timeout: 15)

        AuthConnectionStatus.post(.sendingPhone)
        authLogger.info("setAuthenticationPhoneNumber \(normalized, privacy: .private)")
        do {
            try await AsyncTimeout.withTimeout(seconds: 45, error: AuthError.networkUnavailable) {
                _ = try await client.setAuthenticationPhoneNumber(
                    phoneNumber: normalized,
                    settings: nil
                )
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw mapTDLibError(error)
        }
        AuthConnectionStatus.post(.idle)
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
        _ = try await client.resendAuthenticationCode(reason: nil)
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
        authLogger.debug("authorization state: \(String(describing: state), privacy: .public)")
        switch state {
        case .authorizationStateWaitTdlibParameters:
            await applyTdlibParameters()
        case .authorizationStateWaitPhoneNumber:
            currentState = .waitPhoneNumber
            onStateChange?(currentState)
        case .authorizationStateWaitCode(let waitCode):
            let length = Self.codeLength(from: waitCode.codeInfo)
            let timeout = max(Int(waitCode.codeInfo.timeout), 0)
            currentState = .waitCode(codeLength: length, resendTimeout: timeout > 0 ? timeout : 60)
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
            _ = try await client.setTdlibParameters(
                apiHash: TelegramAPIConfiguration.apiHash,
                apiId: Int(TelegramAPIConfiguration.apiId),
                applicationVersion: TelegramAPIConfiguration.applicationVersion,
                databaseDirectory: TelegramAPIConfiguration.databaseDirectoryPath,
                databaseEncryptionKey: Data(),
                deviceModel: TelegramAPIConfiguration.deviceModel,
                filesDirectory: TelegramAPIConfiguration.filesDirectoryPath,
                systemLanguageCode: TelegramAPIConfiguration.systemLanguageCode,
                systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                useChatInfoDatabase: true,
                useFileDatabase: true,
                useMessageDatabase: true,
                useSecretChats: true,
                useTestDc: false
            )
            parametersApplied = true
        } catch {
            authLogger.error("setTdlibParameters failed: \(error.localizedDescription, privacy: .public)")
            currentState = .closed
            onStateChange?(currentState)
        }
    }

    private func waitForPhoneNumberState(timeout: TimeInterval) async throws {
        if case .waitPhoneNumber = currentState { return }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if case .waitPhoneNumber = currentState { return }
            if case .closed = currentState {
                throw AuthError.tdlibError(L10n.authAuthorizationFailed)
            }

            if let client = TDLibSession.shared.tdClient,
               let state = try? await client.getAuthorizationState() {
                await processAuthorizationState(state)
                if case .authorizationStateWaitPhoneNumber = state { return }
                if case .authorizationStateClosed = state {
                    throw AuthError.tdlibError(L10n.authAuthorizationFailed)
                }
                if case .authorizationStateWaitTdlibParameters = state {
                    AuthConnectionStatus.post(.waitingTdlib)
                    await applyTdlibParameters()
                }
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        if let client = TDLibSession.shared.tdClient,
           let state = try? await client.getAuthorizationState() {
            authLogger.error("Timed out waiting for phone state; TDLib state: \(String(describing: state), privacy: .public)")
        }
        throw AuthError.stillStarting
    }

    private static func codeLength(from codeInfo: AuthenticationCodeInfo) -> Int {
        switch codeInfo.type {
        case .authenticationCodeTypeTelegramMessage(let info):
            return max(Int(info.length), 5)
        case .authenticationCodeTypeSms(let info):
            return max(Int(info.length), 5)
        case .authenticationCodeTypeCall(let info):
            return max(Int(info.length), 5)
        case .authenticationCodeTypeFlashCall(let info):
            return max(info.pattern.count, 5)
        case .authenticationCodeTypeMissedCall(let info):
            return max(Int(info.length), 5)
        case .authenticationCodeTypeFragment(let info):
            return max(Int(info.length), 5)
        default:
            return 5
        }
    }

    private static func normalizePhoneNumber(_ phoneNumber: String) -> String {
        var digits = phoneNumber.filter(\.isNumber)
        guard !digits.isEmpty else { return phoneNumber }

        if !phoneNumber.hasPrefix("+"), digits.hasPrefix("8"), digits.count == 11 {
            digits = String(digits.dropFirst())
        }

        if phoneNumber.hasPrefix("+") {
            return "+\(digits)"
        }
        return "+\(digits)"
    }

    private func mapTDLibError(
        _ error: Swift.Error,
        invalidCode: Bool = false,
        invalidPassword: Bool = false
    ) -> AuthError {
        let message = error.localizedDescription
        let lowered = message.lowercased()

        if lowered.contains("flood") {
            let seconds = Self.extractFloodWaitSeconds(from: message) ?? 60
            return .floodWait(seconds)
        }
        if lowered.contains("network") || lowered.contains("timeout") || lowered.contains("connection") {
            return .networkUnavailable
        }
        if lowered.contains("phone number invalid") || lowered.contains("phone_number_invalid") {
            return .invalidPhoneNumber
        }
        if lowered.contains("wait") && lowered.contains("authorization") {
            return .stillStarting
        }
        if invalidCode, lowered.contains("phone") || lowered.contains("code") || lowered.contains("400") {
            return .invalidCode
        }
        if invalidPassword, lowered.contains("password") || lowered.contains("400") {
            return .invalidPassword
        }
        return .tdlibError(Self.russianErrorMessage(from: message))
    }

    private static func extractFloodWaitSeconds(from message: String) -> Int? {
        let pattern = /(\d+)/
        if let match = message.firstMatch(of: pattern) {
            return Int(match.1)
        }
        return nil
    }

    private static func russianErrorMessage(from message: String) -> String {
        let lowered = message.lowercased()
        if lowered.contains("phone number invalid") || lowered.contains("phone_number_invalid") {
            return L10n.authInvalidPhone
        }
        if lowered.contains("network") || lowered.contains("timeout") {
            return L10n.authNetworkError
        }
        if lowered.contains("flood") {
            let seconds = extractFloodWaitSeconds(from: message) ?? 60
            return L10n.authFloodWait(seconds)
        }
        return message
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
            isVerified: tdUser.verificationStatus?.isVerified ?? false
        )
    }
}
#endif

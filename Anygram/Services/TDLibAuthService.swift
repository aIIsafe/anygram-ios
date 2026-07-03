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
    private var parametersApplyInProgress = false
    private var cachedUser: User?
    private let stateLock = NSLock()
    /// Ensures exactly one setTdlibParameters call per client lifetime.
    private let parametersApplyLock = NSLock()
    private var parametersApplyWaiters: [CheckedContinuation<Void, Never>] = []
    /// Serial queue for setTdlibParameters and other auth bootstrap calls (BetterTG-style).
    private let authQueue = DispatchQueue(label: "com.anygram.tdlib.auth", qos: .userInitiated)

    init() {
        NotificationCenter.default.addObserver(
            forName: TDLibSession.sessionResetNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.stateLock.lock()
            self?.parametersApplied = false
            self?.parametersApplyInProgress = false
            self?.cachedUser = nil
            self?.currentState = .unknown
            self?.stateLock.unlock()
            TDLibAccessGate.shared.reset()
            AppDebugLogger.shared.log("session reset: cleared parametersApplied", category: .AUTH)
        }

        // BetterTG: register auth handler + create client at service init, before any chat/user calls.
        TDLibSession.shared.registerAuthUpdateHandler { [weak self] data, client in
            self?.handleUpdate(data: data, client: client)
        }
        _ = TDLibSession.shared.ensureClient()
    }

    func initialize() async throws {
        AppDebugLogger.shared.log("initialize start", category: .AUTH)
        guard TelegramAPIConfiguration.isConfigured else {
            AppDebugLogger.shared.log("initialize: not configured", category: .ERROR)
            throw AuthError.notConfigured
        }
        TelegramAPIConfiguration.performStorageMigrationIfNeeded()
        AuthConnectionStatus.postProgress(step: 1, total: 7, label: "ensureClient + register handler")
        _ = TDLibSession.shared.ensureClient()
        AuthConnectionStatus.postProgress(step: 2, total: 7, label: "awaitBootstrap (setLogStream → setTdlibParameters → waitPhoneNumber)")
        try await TDLibSession.shared.awaitBootstrap(timeout: 12)

        // BetterTG: sync current state once; apply params if TDLib is still waiting for them.
        AuthConnectionStatus.postProgress(step: 3, total: 7, label: "getAuthorizationState (sync)")
        if let client = TDLibSession.shared.tdClient {
            if let state = try? await getAuthorizationState(client: client, label: "initialize") {
                await processAuthorizationState(state)
                if case .authorizationStateWaitTdlibParameters = state {
                    await applyTdlibParameters()
                    try await waitForPhoneNumberState(timeout: 12)
                } else if case .authorizationStateWaitPhoneNumber = state,
                          !TDLibAccessGate.shared.areParametersApplied {
                    AppDebugLogger.shared.log("[AUTH] initialize: waitPhoneNumber without params — wiping stale DB", category: .AUTH)
                    TelegramAPIConfiguration.wipeTdStorageForRecovery()
                    TDLibSession.shared.resetClient()
                    stateLock.lock()
                    parametersApplied = false
                    stateLock.unlock()
                    try await TDLibSession.shared.awaitBootstrap(timeout: 12)
                }
            }
        }
        AppDebugLogger.shared.log("initialize done, currentState=\(String(describing: currentState)) paramsApplied=\(TDLibAccessGate.shared.areParametersApplied)", category: .AUTH)
    }

    func setPhoneNumber(_ phoneNumber: String) async throws {
        let masked = Self.maskPhone(phoneNumber)
        AppDebugLogger.shared.log("setPhoneNumber start phone=\(masked)", category: .AUTH)

        try await AsyncTimeout.withTimeout(seconds: 15, error: AuthError.tdlibError("TIMEOUT at step submitPhoneNumber (15s)")) {
            try await self.submitPhoneNumberFlow(phoneNumber: phoneNumber, masked: masked)
        }
    }

    private func submitPhoneNumberFlow(
        phoneNumber: String,
        masked: String
    ) async throws {
        guard TDLibSession.shared.tdClient != nil else {
            AppDebugLogger.shared.log("setPhoneNumber: no tdClient", category: .ERROR)
            throw AuthError.notConfigured
        }
        let normalized = Self.normalizePhoneNumber(phoneNumber)
        let digits = normalized.filter(\.isNumber)
        guard digits.count >= 10 else { throw AuthError.invalidPhoneNumber }

        try await ensureTdlibParametersApplied()

        guard let activeClient = TDLibSession.shared.tdClient else {
            throw AuthError.notConfigured
        }

        AuthConnectionStatus.post(.sendingPhone)
        AuthConnectionStatus.postProgress(step: 6, total: 7, label: "setAuthenticationPhoneNumber")
        AppDebugLogger.shared.log("setAuthenticationPhoneNumber \(masked)", category: .AUTH)
        let sendStart = Date()
        do {
            _ = try await AsyncTimeout.withTimeout(seconds: 12, error: AuthError.networkUnavailable) {
                _ = try await activeClient.setAuthenticationPhoneNumber(
                    phoneNumber: normalized,
                    settings: nil
                )
            }
            let ms = Int(Date().timeIntervalSince(sendStart) * 1000)
            AppDebugLogger.shared.log("setAuthenticationPhoneNumber OK (\(ms)ms)", category: .AUTH)
        } catch let error as AuthError {
            AppDebugLogger.shared.log("setAuthenticationPhoneNumber AuthError: \(error.localizedDescription ?? "?")", category: .ERROR)
            if case .networkUnavailable = error {
                AppDebugLogger.shared.log("resetClient after phone send timeout", category: .AUTH)
                TDLibSession.shared.resetClient()
                stateLock.lock()
                parametersApplied = false
                stateLock.unlock()
            }
            throw error
        } catch {
            let rawMessage = Self.rawTDLibErrorMessage(from: error)
            AppDebugLogger.shared.log("setAuthenticationPhoneNumber Telegram error: \(rawMessage)", category: .ERROR)
            let mapped = mapTDLibError(error)
            if Self.isApiIdInvalid(mapped) {
                AppDebugLogger.shared.log("[AUTH] API_ID_INVALID — wiping TDLib DB, resetting client (no retry)", category: .AUTH)
                TelegramAPIConfiguration.wipeTdStorageForRecovery()
                TDLibSession.shared.resetClient()
                stateLock.lock()
                parametersApplied = false
                parametersApplyInProgress = false
                stateLock.unlock()
                throw mapped
            }
            throw mapped
        }
        AuthConnectionStatus.postProgress(step: 7, total: 7, label: "done — wait for waitCode update")
        AuthConnectionStatus.post(.idle)
    }

    /// Ensures setTdlibParameters ran before setAuthenticationPhoneNumber (never submit phone with apiId=0 / stale DB).
    private func ensureTdlibParametersApplied() async throws {
        AuthConnectionStatus.postProgress(step: 4, total: 7, label: "getAuthorizationState before phone")

        for attempt in 0..<2 {
            guard let activeClient = TDLibSession.shared.tdClient else {
                throw AuthError.notConfigured
            }
            let authState = try await getAuthorizationState(
                client: activeClient,
                label: "before phone #\(attempt + 1)"
            )

            switch authState {
            case .authorizationStateWaitTdlibParameters:
                AppDebugLogger.shared.log("[AUTH] waitTdlibParameters — applying params before phone", category: .AUTH)
                AuthConnectionStatus.post(.waitingTdlib)
                AuthConnectionStatus.postProgress(step: 5, total: 7, label: "setTdlibParameters")
                await applyTdlibParameters()
                try await waitForPhoneNumberState(timeout: 12)
                guard TDLibAccessGate.shared.areParametersApplied else {
                    throw AuthError.stillStarting
                }
                AppDebugLogger.shared.log("[AUTH] auth state OK: waitPhoneNumber after setTdlibParameters", category: .AUTH)
                return

            case .authorizationStateWaitPhoneNumber:
                stateLock.lock()
                let applied = parametersApplied
                stateLock.unlock()
                if applied && TDLibAccessGate.shared.areParametersApplied {
                    AppDebugLogger.shared.log("[AUTH] auth state OK: waitPhoneNumber, params verified", category: .AUTH)
                    return
                }
                AppDebugLogger.shared.log("[AUTH] waitPhoneNumber but setTdlibParameters never applied — wiping stale DB", category: .AUTH)
                TelegramAPIConfiguration.wipeTdStorageForRecovery()
                TDLibSession.shared.resetClient()
                stateLock.lock()
                parametersApplied = false
                stateLock.unlock()
                try await TDLibSession.shared.awaitBootstrap(timeout: 12)
                continue

            default:
                let name = Self.authorizationStateName(authState)
                AppDebugLogger.shared.log("[AUTH] unexpected auth state before phone: \(name)", category: .ERROR)
                throw AuthError.stillStarting
            }
        }

        throw AuthError.stillStarting
    }

    func checkAuthenticationCode(_ code: String) async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        let digits = code.filter(\.isNumber)
        guard !digits.isEmpty else { throw AuthError.invalidCode }
        AppDebugLogger.shared.log("checkAuthenticationCode len=\(digits.count)", category: .AUTH)
        do {
            _ = try await AsyncTimeout.withTimeout(seconds: 15, error: AuthError.networkUnavailable) {
                _ = try await client.checkAuthenticationCode(code: code)
            }
        } catch {
            throw mapTDLibError(error, invalidCode: true, invalidPassword: false)
        }
    }

    func checkAuthenticationPassword(_ password: String) async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        guard !password.isEmpty else { throw AuthError.invalidPassword }
        AppDebugLogger.shared.log("checkAuthenticationPassword", category: .AUTH)
        do {
            _ = try await AsyncTimeout.withTimeout(seconds: 15, error: AuthError.networkUnavailable) {
                _ = try await client.checkAuthenticationPassword(password: password)
            }
        } catch {
            throw mapTDLibError(error, invalidCode: false, invalidPassword: true)
        }
    }

    func resendAuthenticationCode() async throws {
        guard let client = TDLibSession.shared.tdClient else { throw AuthError.notConfigured }
        AppDebugLogger.shared.log("resendAuthenticationCode", category: .AUTH)
        _ = try await AsyncTimeout.withTimeout(seconds: 15, error: AuthError.networkUnavailable) {
            _ = try await client.resendAuthenticationCode(reason: nil)
        }
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
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI,
              let client = TDLibSession.shared.tdClient else { return nil }
        let tdUser = try await client.getMe()
        let user = Self.mapTDLibUser(tdUser)
        cachedUser = user
        return user
    }

    private func handleUpdate(data: Data, client: TDLibClient) {
        guard let update = try? client.decoder.decode(Update.self, from: data) else { return }
        if case .updateAuthorizationState(let authUpdate) = update {
            let stateName = Self.authorizationStateName(authUpdate.authorizationState)
            AppDebugLogger.shared.log("updateAuthorizationState: \(stateName)", category: .TDLIB)
            if case .authorizationStateWaitTdlibParameters = authUpdate.authorizationState {
                Task { await self.applyTdlibParameters() }
            } else {
                Task { await self.processAuthorizationState(authUpdate.authorizationState) }
            }
        }
    }

    private func getAuthorizationState(client: TDLibClient, label: String) async throws -> AuthorizationState {
        AppDebugLogger.shared.log("getAuthorizationState (\(label))", category: .TDLIB)
        return try await AsyncTimeout.withTimeout(seconds: 5, error: AuthError.stillStarting) {
            try await client.getAuthorizationState()
        }
    }

    private func processAuthorizationState(_ state: AuthorizationState) async {
        let name = Self.authorizationStateName(state)
        authLogger.debug("authorization state: \(name, privacy: .public)")
        AppDebugLogger.shared.log("processAuthorizationState: \(name)", category: .AUTH)

        switch state {
        case .authorizationStateWaitTdlibParameters:
            AppDebugLogger.shared.log("[AUTH] waitTdlibParameters (state sync only — apply via update handler)", category: .AUTH)
        case .authorizationStateWaitPhoneNumber:
            TDLibSession.shared.markBootstrapComplete()
            currentState = .waitPhoneNumber
            onStateChange?(currentState)
        case .authorizationStateWaitCode(let waitCode):
            let length = Self.codeLength(from: waitCode.codeInfo)
            let timeout = max(Int(waitCode.codeInfo.timeout), 0)
            currentState = .waitCode(codeLength: length, resendTimeout: timeout > 0 ? timeout : 60)
            onStateChange?(currentState)
            TDLibSession.shared.markBootstrapComplete()
        case .authorizationStateWaitPassword(let info):
            currentState = .waitPassword(hint: info.passwordHint)
            onStateChange?(currentState)
        case .authorizationStateWaitRegistration:
            currentState = .waitRegistration
            onStateChange?(currentState)
        case .authorizationStateReady:
            currentState = .ready
            onStateChange?(currentState)
            TDLibAccessGate.shared.markAuthorized()
            TDLibSession.shared.markBootstrapComplete()
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            authQueue.async {
                Task {
                    await self.applyTdlibParametersSingleFlight(finish: continuation)
                }
            }
        }
    }

    /// Single-flight: concurrent callers queue on waiters instead of duplicate setTdlibParameters.
    private func applyTdlibParametersSingleFlight(finish: CheckedContinuation<Void, Never>) async {
        parametersApplyLock.lock()
        if parametersApplied {
            parametersApplyLock.unlock()
            AppDebugLogger.shared.log("[AUTH] setTdlibParameters skipped: already applied", category: .AUTH)
            finish.resume()
            return
        }
        if parametersApplyInProgress {
            parametersApplyWaiters.append(finish)
            parametersApplyLock.unlock()
            return
        }
        parametersApplyInProgress = true
        parametersApplyLock.unlock()

        defer {
            parametersApplyLock.lock()
            parametersApplyInProgress = false
            let waiters = parametersApplyWaiters
            parametersApplyWaiters = []
            parametersApplyLock.unlock()
            finish.resume()
            for waiter in waiters {
                waiter.resume()
            }
        }

        guard let client = TDLibSession.shared.tdClient else { return }

        let apiId = Int(TelegramAPIConfiguration.apiId)
        guard apiId > 0 else {
            AppDebugLogger.shared.log("[AUTH] setTdlibParameters aborted: apiId=0", category: .ERROR)
            return
        }

        AppDebugLogger.shared.log(
            "[AUTH] setTdlibParameters apiId=\(apiId) apiHash=\(TelegramAPIConfiguration.maskedApiHash)",
            category: .AUTH
        )
        AuthConnectionStatus.postProgress(step: 5, total: 7, label: "setTdlibParameters")
        let start = Date()
        do {
            _ = try await AsyncTimeout.withTimeout(seconds: 10, error: AuthError.stillStarting) {
                _ = try await client.setTdlibParameters(
                    apiHash: TelegramAPIConfiguration.apiHash,
                    apiId: apiId,
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
            }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            parametersApplyLock.lock()
            parametersApplied = true
            parametersApplyLock.unlock()
            AppDebugLogger.shared.log("[AUTH] setTdlibParameters OK (\(ms)ms)", category: .AUTH)
            TDLibAccessGate.shared.markParametersApplied()
            await TDLibProxyApplier.applyDefaultProxy(client: client)
        } catch {
            let rawMessage = Self.rawTDLibErrorMessage(from: error)
            let isDuplicateApply = rawMessage.localizedCaseInsensitiveContains("unexpected settdlibparameters")
            parametersApplyLock.lock()
            let wasAlreadyApplied = parametersApplied || TDLibAccessGate.shared.areParametersApplied
            parametersApplyLock.unlock()

            if isDuplicateApply && wasAlreadyApplied {
                AppDebugLogger.shared.log("[AUTH] setTdlibParameters: ignored duplicate (\(rawMessage))", category: .AUTH)
                return
            }

            parametersApplyLock.lock()
            parametersApplied = false
            parametersApplyLock.unlock()
            AppDebugLogger.shared.log("[AUTH] setTdlibParameters FAILED: \(rawMessage)", category: .ERROR)
            authLogger.error("setTdlibParameters failed: \(rawMessage, privacy: .public)")
            currentState = .closed
            onStateChange?(currentState)
        }
    }

    /// Poll getAuthorizationState until waitPhoneNumber — capped timeout (was 30s in initialize, caused hang).
    private func waitForPhoneNumberState(timeout: TimeInterval) async throws {
        if case .waitPhoneNumber = currentState { return }

        AuthConnectionStatus.post(.waitingTdlib)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if case .waitPhoneNumber = currentState { return }
            if case .closed = currentState {
                throw AuthError.tdlibError(L10n.authAuthorizationFailed)
            }

            if let client = TDLibSession.shared.tdClient,
               let state = try? await getAuthorizationState(client: client, label: "waitForPhone") {
                await processAuthorizationState(state)
                if case .authorizationStateWaitPhoneNumber = state { return }
                if case .authorizationStateClosed = state {
                    throw AuthError.tdlibError(L10n.authAuthorizationFailed)
                }
                if case .authorizationStateWaitTdlibParameters = state {
                    await applyTdlibParameters()
                }
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        if let client = TDLibSession.shared.tdClient,
           let state = try? await getAuthorizationState(client: client, label: "waitForPhone timeout") {
            let name = Self.authorizationStateName(state)
            AppDebugLogger.shared.log("TIMEOUT at waitForPhoneNumberState; TDLib=\(name)", category: .ERROR)
            authLogger.error("Timed out waiting for phone state; TDLib state: \(name, privacy: .public)")
        }
        TDLibSession.shared.resetClient()
        stateLock.lock()
        parametersApplied = false
        stateLock.unlock()
        throw AuthError.stillStarting
    }

    private static func isApiIdInvalid(_ error: AuthError) -> Bool {
        if case .tdlibError(let message) = error {
            return message.lowercased().contains("api_id_invalid")
        }
        return false
    }

    private static func authorizationStateName(_ state: AuthorizationState) -> String {
        switch state {
        case .authorizationStateWaitTdlibParameters: return "authorizationStateWaitTdlibParameters"
        case .authorizationStateWaitPhoneNumber: return "authorizationStateWaitPhoneNumber"
        case .authorizationStateWaitCode: return "authorizationStateWaitCode"
        case .authorizationStateWaitPassword: return "authorizationStateWaitPassword"
        case .authorizationStateWaitRegistration: return "authorizationStateWaitRegistration"
        case .authorizationStateReady: return "authorizationStateReady"
        case .authorizationStateClosed: return "authorizationStateClosed"
        case .authorizationStateLoggingOut: return "authorizationStateLoggingOut"
        case .authorizationStateClosing: return "authorizationStateClosing"
        case .authorizationStateWaitEmailAddress: return "authorizationStateWaitEmailAddress"
        case .authorizationStateWaitEmailCode: return "authorizationStateWaitEmailCode"
        case .authorizationStateWaitOtherDeviceConfirmation: return "authorizationStateWaitOtherDeviceConfirmation"
        case .authorizationStateWaitPremiumPurchase: return "authorizationStateWaitPremiumPurchase"
        }
    }

    private static func maskPhone(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        guard digits.count > 4 else { return "+***" }
        return "+\(digits.prefix(2))***\(digits.suffix(2))"
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

    private static func rawTDLibErrorMessage(from error: Swift.Error) -> String {
        let nsError = error as NSError
        if nsError.domain.contains("TDLib") || nsError.localizedDescription.contains("TDLib") {
            if let message = nsError.userInfo["message"] as? String, !message.isEmpty {
                return message
            }
        }
        if let message = (error as? LocalizedError)?.errorDescription, !message.isEmpty {
            return message
        }
        let description = error.localizedDescription
        if description.contains("API_ID_INVALID") { return "API_ID_INVALID" }
        if description.contains("Unexpected setTdlibParameters") { return "Unexpected setTdlibParameters" }
        return description
    }

    private func mapTDLibError(
        _ error: Swift.Error,
        invalidCode: Bool = false,
        invalidPassword: Bool = false
    ) -> AuthError {
        let message = Self.rawTDLibErrorMessage(from: error)
        let lowered = message.lowercased()

        if lowered.contains("api_id_invalid") {
            return .tdlibError("\(L10n.authInvalidApiId) (\(message))")
        }
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
        if lowered.contains("api_id_invalid") {
            return "\(L10n.authInvalidApiId) (\(message))"
        }
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

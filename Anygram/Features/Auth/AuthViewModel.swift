import Combine
import Foundation

enum AuthStep: Equatable {
    case phone
    case code
    case twoFactor
    case loading
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var step: AuthStep = .phone
    @Published var selectedCountry: Country = .default
    @Published var phoneLocal = ""
    @Published var codeDigits = Array(repeating: "", count: 5)
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var connectionPhase: AuthConnectionPhase = .idle
    @Published var resendSeconds = 0
    @Published var passwordHint: String?
    @Published var codeLength = 5
    @Published var flowProgressText: String?
    @Published var loadingElapsedSeconds = 0
    @Published var recentLogLines: [String] = []
    @Published var showOpenLogsAfterError = false
    @Published var showDebugLogs = false

    private let authRepository: AuthRepository
    private var resendTimer: Timer?
    private var loadingTimer: Timer?
    private var logRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        syncStepFromState(authRepository.authorizationState)
        authRepository.authorizationStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncStepFromState(state)
            }
            .store(in: &cancellables)

        AuthConnectionStatus.publisher()
            .compactMap { $0.object as? AuthConnectionPhase }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard let self else { return }
                AppDebugLogger.shared.log("connectionPhase → \(String(describing: phase))", category: .UI)
                self.connectionPhase = phase
            }
            .store(in: &cancellables)

        AuthConnectionStatus.progressPublisher()
            .compactMap { $0.object as? AuthFlowProgress }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.flowProgressText = progress.displayText
            }
            .store(in: &cancellables)

        AppDebugLogger.shared.$revision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recentLogLines = AppDebugLogger.shared.recentLines(3)
            }
            .store(in: &cancellables)
    }

    var connectionStatusText: String? {
        switch connectionPhase {
        case .idle:
            return nil
        case .connectingProxy:
            return L10n.authConnectingProxy
        case .waitingTdlib:
            return L10n.authWaitingTdlib
        case .sendingPhone:
            return L10n.authSendingPhone
        }
    }

    var formattedPhone: String {
        PhoneFormatter.format(phoneLocal, country: selectedCountry)
    }

    var fullPhoneNumber: String {
        PhoneFormatter.internationalNumber(
            dialCode: selectedCountry.dialCode,
            localNumber: phoneLocal,
            country: selectedCountry
        )
    }

    var usesScaffoldAuth: Bool {
        authRepository.usesScaffoldAuth
    }

    var isAuthenticated: Bool {
        authRepository.isAuthenticated
    }

    func submitPhone() async {
        guard !phoneLocal.filter(\.isNumber).isEmpty else {
            errorMessage = L10n.authInvalidPhone
            return
        }
        AppDebugLogger.shared.log("submitPhone tapped phone=\(fullPhoneNumber.filter(\.isNumber).suffix(4))…", category: .UI)
        isLoading = true
        errorMessage = nil
        showOpenLogsAfterError = false
        flowProgressText = "Шаг 0/7: начало"
        startLoadingTimers()

        defer {
            stopLoadingTimers()
            isLoading = false
            connectionPhase = .idle
            flowProgressText = nil
            loadingElapsedSeconds = 0
            AppDebugLogger.shared.log("submitPhone end isLoading=false", category: .UI)
        }

        let phone = fullPhoneNumber
        let repository = authRepository
        do {
            // Don't block MainActor waiting for TDLib — run auth on background executor.
            try await Task.detached(priority: .userInitiated) {
                AppDebugLogger.shared.log("submitPhone Task.detached start", category: .AUTH)
                try await repository.submitPhoneNumber(phone)
                AppDebugLogger.shared.log("submitPhone Task.detached success", category: .AUTH)
            }.value
        } catch {
            AppDebugLogger.shared.log("submitPhone error: \(error.localizedDescription)", category: .ERROR)
            errorMessage = error.localizedDescription
            if error.localizedDescription.contains("TIMEOUT") || (error as? AuthError) == .stillStarting {
                showOpenLogsAfterError = true
            }
        }
    }

    func submitCode() async {
        let code = codeDigits.joined()
        guard code.count >= codeLength else {
            errorMessage = L10n.authInvalidCode
            return
        }
        isLoading = true
        errorMessage = nil
        startLoadingTimers()
        defer {
            stopLoadingTimers()
            isLoading = false
        }
        let repository = authRepository
        do {
            try await Task.detached(priority: .userInitiated) {
                try await repository.submitCode(code)
            }.value
        } catch {
            errorMessage = error.localizedDescription
            codeDigits = Array(repeating: "", count: codeLength)
        }
    }

    func submitPassword() async {
        guard !password.isEmpty else {
            errorMessage = L10n.authInvalidPassword
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let repository = authRepository
        let passwordToSubmit = password
        do {
            try await Task.detached(priority: .userInitiated) {
                try await repository.submitPassword(passwordToSubmit)
            }.value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resendCode() async {
        guard resendSeconds == 0 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authRepository.resendCode()
            startResendTimer(60)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCodeDigit(at index: Int, value: String) {
        guard index >= 0, index < codeDigits.count else { return }
        let filtered = value.filter(\.isNumber)
        if filtered.count <= 1 {
            codeDigits[index] = String(filtered.prefix(1))
            if !codeDigits[index].isEmpty, index < codeDigits.count - 1 {
                focusNextIndex = index + 1
            }
        } else if filtered.count == codeLength {
            for (i, char) in filtered.prefix(codeLength).enumerated() {
                codeDigits[i] = String(char)
            }
            Task { await submitCode() }
        }
        if codeDigits.allSatisfy({ !$0.isEmpty }) {
            Task { await submitCode() }
        }
    }

    @Published var focusNextIndex: Int?

    func goBackToPhone() {
        step = .phone
        codeDigits = Array(repeating: "", count: codeLength)
        errorMessage = nil
        resendTimer?.invalidate()
        resendSeconds = 0
    }

    private func startLoadingTimers() {
        loadingElapsedSeconds = 0
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadingElapsedSeconds += 1
            }
        }
        recentLogLines = AppDebugLogger.shared.recentLines(3)
    }

    private func stopLoadingTimers() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }

    private func syncStepFromState(_ state: AuthAuthorizationState) {
        switch state {
        case .waitPhoneNumber, .closed, .unknown:
            step = .phone
        case .waitCode(let length, let timeout):
            codeLength = max(length, 5)
            if codeDigits.count != codeLength {
                codeDigits = Array(repeating: "", count: codeLength)
            }
            step = .code
            if resendSeconds == 0, timeout > 0 {
                startResendTimer(timeout)
            }
        case .waitPassword(let hint):
            passwordHint = hint
            step = .twoFactor
        case .waitRegistration:
            step = .twoFactor
        case .ready:
            step = .phone
        }
    }

    private func startResendTimer(_ seconds: Int) {
        resendTimer?.invalidate()
        resendSeconds = seconds
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }
                if self.resendSeconds > 0 {
                    self.resendSeconds -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

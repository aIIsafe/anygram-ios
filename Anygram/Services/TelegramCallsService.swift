import Combine
import Foundation

/// Production call history — TDLib when available, otherwise mock data.
public final class TelegramCallsService: CallsServiceProtocol, @unchecked Sendable {
    #if USE_SCAFFOLD_AUTH
    private let backend: MockCallsService
    #elseif targetEnvironment(simulator)
    private let backend: MockCallsService
    #elseif canImport(TDLibKit)
    private let backend: TDLibCallsService
    #else
    private let backend: MockCallsService
    #endif

    public init() {
        #if USE_SCAFFOLD_AUTH
        self.backend = MockCallsService()
        #elseif targetEnvironment(simulator)
        self.backend = MockCallsService()
        #elseif canImport(TDLibKit)
        self.backend = TDLibCallsService()
        #else
        self.backend = MockCallsService()
        #endif
    }

    public func fetchCalls(filter: CallFilter) async throws -> [Call] {
        try await backend.fetchCalls(filter: filter)
    }

    public func deleteCall(_ callID: UUID) async throws {
        try await backend.deleteCall(callID)
    }

    public func observeCalls() -> AnyPublisher<[Call], Never> {
        backend.observeCalls()
    }
}

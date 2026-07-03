import Combine
import Foundation

/// Contract for call history operations.
public protocol CallsServiceProtocol: Sendable {
    func fetchCalls(filter: CallFilter) async throws -> [Call]
    func deleteCall(_ callID: UUID) async throws
    func observeCalls() -> AnyPublisher<[Call], Never>
}

/// Filter options for call history.
public enum CallFilter: Sendable {
    case all
    case missed
}

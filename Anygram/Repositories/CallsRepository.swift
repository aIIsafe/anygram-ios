import Combine
import Foundation

/// Repository mediating call history between ViewModels and services.
@MainActor
public final class CallsRepository: ObservableObject {
    private let callsService: CallsServiceProtocol

    public init(callsService: CallsServiceProtocol) {
        self.callsService = callsService
    }

    public func fetchCalls(filter: CallFilter) async throws -> [Call] {
        try await callsService.fetchCalls(filter: filter)
    }

    public func deleteCall(_ callID: UUID) async throws {
        try await callsService.deleteCall(callID)
    }
}

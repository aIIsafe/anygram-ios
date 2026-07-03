import Combine
import Foundation

/// In-memory mock implementation of call history.
public final class MockCallsService: CallsServiceProtocol, @unchecked Sendable {
    private var calls: [Call]
    private let callsSubject: CurrentValueSubject<[Call], Never>
    private let lock = NSLock()

    public init() {
        let users = MockDataGenerator.generateUsers()
        self.calls = MockDataGenerator.generateCalls(users: users)
        self.callsSubject = CurrentValueSubject(calls)
    }

    public func fetchCalls(filter: CallFilter) async throws -> [Call] {
        lock.lock()
        defer { lock.unlock() }
        switch filter {
        case .all:
            return calls.sorted { $0.date > $1.date }
        case .missed:
            return calls.filter { $0.direction == .missed }.sorted { $0.date > $1.date }
        }
    }

    public func deleteCall(_ callID: UUID) async throws {
        lock.lock()
        calls.removeAll { $0.id == callID }
        let updated = calls
        lock.unlock()
        callsSubject.send(updated)
    }

    public func observeCalls() -> AnyPublisher<[Call], Never> {
        callsSubject.eraseToAnyPublisher()
    }
}


import Foundation

enum AsyncTimeout {
    static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        error: @autoclosure @Sendable () -> Error,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw error()
            }
            guard let result = try await group.next() else {
                throw error()
            }
            group.cancelAll()
            return result
        }
    }

    static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        error: @autoclosure @Sendable () -> Error,
        operation: @escaping @Sendable () async -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw error()
            }
            guard let result = try await group.next() else {
                throw error()
            }
            group.cancelAll()
            return result
        }
    }
}

import Foundation

enum AsyncTimeout {
    static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        error: @autoclosure @Sendable () -> Error,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeoutError = error()
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                AppDebugLogger.shared.log("TIMEOUT fired after \(seconds)s", category: .ERROR)
                throw timeoutError
            }
            guard let result = try await group.next() else {
                throw timeoutError
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
        let timeoutError = error()
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                AppDebugLogger.shared.log("TIMEOUT fired after \(seconds)s", category: .ERROR)
                throw timeoutError
            }
            guard let result = try await group.next() else {
                throw timeoutError
            }
            group.cancelAll()
            return result
        }
    }
}

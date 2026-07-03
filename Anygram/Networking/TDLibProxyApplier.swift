import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Applies the built-in MTProto proxy to TDLib, matching BetterTG `TelegramProxy.swift`.
enum TDLibProxyApplier {
    private static let retryDelayNanoseconds: UInt64 = 3_000_000_000
    private static let maxAttempts = 5
    private static let perAttemptTimeout: TimeInterval = 15
    private static let lock = NSLock()
    private static var appliedProxyID: UUID?

    static func applyForcedProxy(client: TDLibClient, proxy: Anygram.Proxy? = nil) async throws {
        let activeProxy: Anygram.Proxy
        if let proxy {
            activeProxy = proxy
        } else if let bridged = await TDLibProxyBridge.shared.activeProxy {
            activeProxy = bridged
        } else {
            activeProxy = Anygram.Proxy.builtInDefault
        }

        lock.lock()
        if appliedProxyID == activeProxy.id {
            lock.unlock()
            return
        }
        lock.unlock()

        AuthConnectionStatus.post(.connectingProxy)
        var lastError: AuthError?

        for attempt in 1...maxAttempts {
            do {
                _ = try await AsyncTimeout.withTimeout(
                    seconds: perAttemptTimeout,
                    error: AuthError.networkUnavailable
                ) {
                    try await client.addProxy(
                        enable: true,
                        port: activeProxy.port,
                        server: activeProxy.server,
                        type: .proxyTypeMtproto(
                            ProxyTypeMtproto(secret: activeProxy.secret)
                        )
                    )
                }
                await TDLibProxyBridge.shared.configure(proxy: activeProxy)
                lock.lock()
                appliedProxyID = activeProxy.id
                lock.unlock()
                return
            } catch {
                lastError = mapProxyError(error)
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                }
            }
        }

        throw lastError ?? AuthError.proxyConnectionFailed
    }

    static func resetAppliedProxy() {
        lock.lock()
        appliedProxyID = nil
        lock.unlock()
    }

    private static func mapProxyError(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }
        return .proxyConnectionFailed
    }
}
#endif

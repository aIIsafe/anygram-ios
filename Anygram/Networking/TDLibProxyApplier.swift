import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Applies the built-in MTProto proxy to TDLib, matching BetterTG `TelegramProxy.swift`.
enum TDLibProxyApplier {
    private static let perAttemptTimeout: TimeInterval = 10
    private static let lock = NSLock()
    private static var appliedProxyID: UUID?

    static func applyForcedProxy(client: TDLibClient, proxy: Anygram.Proxy? = nil) async throws {
        let candidates = await proxyCandidates(preferred: proxy)
        AuthConnectionStatus.post(.connectingProxy)
        defer { AuthConnectionStatus.post(.idle) }

        var lastError: AuthError?
        for activeProxy in candidates {
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
            } catch let authError as AuthError {
                lastError = authError
            } catch {
                lastError = .proxyConnectionFailed
            }
        }

        throw lastError ?? AuthError.proxyConnectionFailed
    }

    static func resetAppliedProxy() {
        lock.lock()
        appliedProxyID = nil
        lock.unlock()
    }

    private static func proxyCandidates(preferred: Anygram.Proxy?) async -> [Anygram.Proxy] {
        if let preferred {
            return [preferred]
        }
        if let bridged = await TDLibProxyBridge.shared.activeProxy {
            var candidates = [bridged]
            for fallback in Anygram.Proxy.builtInFallbacks where fallback.id != bridged.id {
                candidates.append(fallback)
            }
            return candidates
        }
        return [Anygram.Proxy.builtInDefault] + Anygram.Proxy.builtInFallbacks
    }
}
#endif

import Foundation
import os

#if canImport(TDLibKit)
import TDLibKit

private let proxyLogger = Logger(subsystem: "com.anygram.app", category: "TDLibProxy")

/// Applies the built-in MTProto proxy to TDLib, matching BetterTG `TelegramProxy.swift`.
enum TDLibProxyApplier {
    private static let addProxyTimeout: TimeInterval = 5
    private static let lock = NSLock()
    private static var appliedProxyID: UUID?

    /// BetterTG: call addProxy once at client startup — no ping wait, no throw on failure.
    static func applyDefaultProxy(client: TDLibClient, proxy: Anygram.Proxy? = nil) async {
        let candidates = await proxyCandidates(preferred: proxy)

        for activeProxy in candidates {
            if isAlreadyApplied(activeProxy) {
                proxyLogger.debug("Proxy already applied: \(activeProxy.server, privacy: .public):\(activeProxy.port)")
                return
            }

            do {
                _ = try await AsyncTimeout.withTimeout(
                    seconds: addProxyTimeout,
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
                proxyLogger.info("MTProto proxy enabled: \(activeProxy.server, privacy: .public):\(activeProxy.port)")
                return
            } catch {
                proxyLogger.error("addProxy failed for \(activeProxy.server, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func resetAppliedProxy() {
        lock.lock()
        appliedProxyID = nil
        lock.unlock()
    }

    private static func isAlreadyApplied(_ proxy: Anygram.Proxy) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return appliedProxyID == proxy.id
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

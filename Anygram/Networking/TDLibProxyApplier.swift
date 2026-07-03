import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Applies the built-in MTProto proxy to TDLib, matching BetterTG `TelegramProxy.swift`.
enum TDLibProxyApplier {
    private static let addProxyTimeout: TimeInterval = 3
    private static let lock = NSLock()
    private static var appliedProxyID: UUID?

    /// BetterTG: call addProxy once at client startup — no ping wait, no throw on failure.
    static func applyDefaultProxy(client: TDLibClient, proxy: Anygram.Proxy? = nil) async {
        let candidates = await proxyCandidates(preferred: proxy)
        AppDebugLogger.shared.log("addProxy candidates: \(candidates.count)", category: .PROXY)

        for activeProxy in candidates {
            if isAlreadyApplied(activeProxy) {
                AppDebugLogger.shared.log("Proxy already applied: \(activeProxy.server):\(activeProxy.port)", category: .PROXY)
                return
            }

            let maskedSecret = activeProxy.secret.prefix(4) + "…"
            AppDebugLogger.shared.log(
                "addProxy start server=\(activeProxy.server) port=\(activeProxy.port) secret=\(maskedSecret)",
                category: .PROXY
            )
            let start = Date()

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
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                await TDLibProxyBridge.shared.configure(proxy: activeProxy)
                lock.lock()
                appliedProxyID = activeProxy.id
                lock.unlock()
                AppDebugLogger.shared.log("addProxy OK \(activeProxy.server):\(activeProxy.port) (\(ms)ms)", category: .PROXY)
                return
            } catch {
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                let isTimeout = (error as? AuthError).map { err in
                    if case .networkUnavailable = err { return true }
                    return false
                } ?? false
                AppDebugLogger.shared.log(
                    isTimeout
                        ? "addProxy TIMEOUT \(activeProxy.server):\(activeProxy.port) (\(ms)ms) — continuing (BetterTG-style)"
                        : "addProxy FAILED \(activeProxy.server): \(error.localizedDescription) (\(ms)ms)",
                    category: isTimeout ? .PROXY : .ERROR
                )
            }
        }
        AppDebugLogger.shared.log("addProxy: all candidates failed (non-fatal, BetterTG-style)", category: .PROXY)
    }

    static func resetAppliedProxy() {
        lock.lock()
        appliedProxyID = nil
        lock.unlock()
        AppDebugLogger.shared.log("resetAppliedProxy", category: .PROXY)
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

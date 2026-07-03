import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Applies the built-in MTProto proxy to TDLib, matching the Flutter ProxyService behavior.
enum TDLibProxyApplier {
    private static let retryDelayNanoseconds: UInt64 = 3_000_000_000

    static func applyForcedProxy(client: TDLibClient, proxy: Anygram.Proxy? = nil) async {
        let activeProxy: Anygram.Proxy
        if let proxy {
            activeProxy = proxy
        } else if let bridged = await TDLibProxyBridge.shared.activeProxy {
            activeProxy = bridged
        } else {
            activeProxy = Anygram.Proxy.builtInDefault
        }
        var attempt = 0

        while attempt < 10 {
            attempt += 1
            do {
                _ = try await client.addProxy(
                    enable: true,
                    port: activeProxy.port,
                    server: activeProxy.server,
                    type: .proxyTypeMtproto(
                        ProxyTypeMtproto(secret: activeProxy.secret)
                    )
                )
                await TDLibProxyBridge.shared.configure(proxy: activeProxy)
                return
            } catch {
                if attempt >= 10 { return }
            }
            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }
    }
}
#endif

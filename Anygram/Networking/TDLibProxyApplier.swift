import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// Applies the built-in MTProto proxy to TDLib, matching the Flutter ProxyService behavior.
enum TDLibProxyApplier {
    private static let retryDelayNanoseconds: UInt64 = 3_000_000_000

    static func applyForcedProxy(client: TDLibClient, proxy: Anygram.Proxy? = nil) async {
        let activeProxy = proxy ?? await TDLibProxyBridge.shared.activeProxy ?? Anygram.Proxy.builtInDefault
        var attempt = 0

        while attempt < 10 {
            attempt += 1
            do {
                let secretData = Data(hexString: activeProxy.secret)
                    ?? Data(base64Encoded: activeProxy.secret)
                    ?? Data(activeProxy.secret.utf8)

                _ = try await client.addProxy(
                    server: activeProxy.server,
                    port: activeProxy.port,
                    enable: true,
                    type: .proxyTypeMtproto(secret: secretData)
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

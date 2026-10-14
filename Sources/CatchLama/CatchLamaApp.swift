import AppKit
import SwiftUI

@main
struct CatchLamaApp: App {
    @State private var keys: KeyStore
    @State private var proxy: ProxyServer

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)  // Dock'ta ikon yok (bundle'da LSUIElement de var)
        let keys = KeyStore()
        let proxy = ProxyServer()
        proxy.start(keys: keys)
        _keys = State(initialValue: keys)
        _proxy = State(initialValue: proxy)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(keys: keys, proxy: proxy)
        } label: {
            Image(nsImage: proxy.active > 0 ? Self.busyIcon : Self.idleIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private static let idleIcon = menuIcon("MenuIdle")
    private static let busyIcon = menuIcon("MenuBusy")

    /// .app içindeki Resources'tan; `swift run`'da (bundle yok) SF Symbol'e düşer
    private static func menuIcon(_ name: String) -> NSImage {
        let image = Bundle.main.image(forResource: name) ?? NSImage(systemSymbolName: "lasso", accessibilityDescription: nil)!
        image.size = NSSize(width: 22, height: 22)
        image.isTemplate = true  // açık/koyu menü çubuğuna göre macOS boyar
        return image
    }
}

import Foundation
import Testing
@testable import CatchLama

@MainActor @Test func keyLifecycle() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: "catchlama-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: file) }

    let store = KeyStore(file: file)
    let secret = try #require(store.create(name: "test").secret)
    #expect(secret.hasPrefix("clk-"))
    #expect(store.validate(secret))
    #expect(!store.validate("clk-yanlis"))
    #expect(!store.validate(""))

    // diskten tekrar yüklenince geçerli ve tam hali görünür; dosya sadece kullanıcıya açık
    let reloaded = KeyStore(file: file)
    #expect(reloaded.validate(secret))
    #expect(reloaded.keys.first?.secret == secret)
    let perms = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
    #expect(perms == 0o600)

    store.revoke(store.keys[0].id)
    #expect(!store.validate(secret))
}

@Test func templatesFillEveryPlaceholder() {
    for t in Template.allCases {
        let env = t.env(model: "qwen2.5:3b", key: "clk-abc"), code = t.code(model: "qwen2.5:3b")
        #expect(env.contains("clk-abc"), "\(t.rawValue)")
        #expect((env + code).contains("qwen2.5:3b"), "\(t.rawValue)")  // Spring AI'da model properties'te
        #expect(!code.contains("{{"), "\(t.rawValue)")
    }
}

@Test func popoverCentersUnderIconAndStaysOnScreen() {
    let main = CGRect(x: 0, y: 0, width: 1728, height: 1080)
    #expect(centeredX(iconX: 864, width: 840, screen: main) == 444)    // ortada: tam ortalı
    #expect(centeredX(iconX: 1650, width: 840, screen: main) == 880)   // sağa yakın: 1728 - 840 - 8
    #expect(centeredX(iconX: 100, width: 840, screen: main) == 8)      // sola yakın
    let external = CGRect(x: 1728, y: 55, width: 1920, height: 1145)   // ikinci monitör
    #expect(centeredX(iconX: 3500, width: 840, screen: external) == 2800)  // 1728 + 1920 - 840 - 8
}

import Foundation
import Testing
@testable import CatchLama

@MainActor @Test func keyLifecycle() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: "catchlama-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: file) }

    let store = KeyStore(file: file)
    let secret = store.create(name: "test")
    #expect(secret.hasPrefix("clk-"))
    #expect(store.validate(secret))
    #expect(!store.validate("clk-yanlis"))
    #expect(!store.validate(""))

    // diskten tekrar yüklenince de geçerli; ama düz key dosyada yok
    #expect(KeyStore(file: file).validate(secret))
    #expect(try !String(contentsOf: file, encoding: .utf8).contains(secret))

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

import CryptoKit
import Foundation
import Observation

struct APIKey: Codable, Identifiable {
    let id: UUID
    let name: String
    let prefix: String  // listede gösterilen "clk-a1b2c3"
    let sha256: String  // key'in kendisi diske yazılmaz
    let createdAt: Date
    var lastUsedAt: Date?
}

/// Key'leri üretir, saklar, doğrular. UI ve proxy aynı örneği kullanır;
/// MainActor'da yaşadığı için iki taraf aynı anda yazamaz.
@MainActor @Observable
final class KeyStore {
    private(set) var keys: [APIKey] = []
    private let file: URL

    init(file: URL = URL.applicationSupportDirectory.appending(path: "CatchLama/keys.json")) {
        self.file = file
        if let data = try? Data(contentsOf: file) {
            keys = (try? JSONDecoder().decode([APIKey].self, from: data)) ?? []
        }
    }

    /// Yeni key üretir ve düz halini bir kez döner. Sonra sadece hash'i kalır.
    func create(name: String) -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max) }  // SystemRandomNumberGenerator: kriptografik
        let secret = "clk-" + Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        keys.append(APIKey(id: UUID(), name: name, prefix: String(secret.prefix(10)),
                           sha256: Self.hash(secret), createdAt: .now))
        save()
        return secret
    }

    func revoke(_ id: UUID) {
        keys.removeAll { $0.id == id }
        save()
    }

    func validate(_ secret: String) -> Bool {
        let h = Self.hash(secret)
        guard let i = keys.firstIndex(where: { $0.sha256 == h }) else { return false }
        keys[i].lastUsedAt = .now
        save()
        return true
    }

    private func save() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(keys).write(to: file, options: .atomic)
    }

    private static func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

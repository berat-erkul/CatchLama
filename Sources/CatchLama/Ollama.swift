import Foundation

struct OllamaModel: Decodable, Identifiable, Hashable {
    let name: String
    let capabilities: [String]?  // completion, tools, vision, thinking, embedding
    var id: String { name }
}

enum Ollama {
    /// nil → Ollama kapalı
    static func models() async -> [OllamaModel]? {
        struct Tags: Decodable { let models: [OllamaModel] }
        guard let (data, _) = try? await URLSession.shared.data(from: URL(string: ProxyServer.ollama + "/api/tags")!) else { return nil }
        return try? JSONDecoder().decode(Tags.self, from: data).models
    }
}

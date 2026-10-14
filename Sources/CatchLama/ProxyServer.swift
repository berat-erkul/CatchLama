import AsyncHTTPClient
import Hummingbird
import Observation

/// 127.0.0.1:11435'te dinler. Key'i doğrular, isteği olduğu gibi Ollama'ya iletir,
/// cevabı (SSE stream dahil) chunk chunk geri akıtır.
@MainActor @Observable
final class ProxyServer {
    nonisolated static let port = 11435
    nonisolated static let ollama = "http://127.0.0.1:11434"
    private(set) var error: String?  // nil → çalışıyor
    private(set) var active = 0      // devam eden istek sayısı; menü çubuğu ikonu buna bakar

    func start(keys: KeyStore) {
        Task {
            do {
                try await Self.makeApp(keys: keys, server: self).run()  // run(): sinyal yakalamaz, Quit/SIGTERM süreci direkt kapatır
            } catch {
                self.error = "\(error)"
            }
        }
    }

    func begin() { active += 1 }

    func end() {
        Task {
            try? await Task.sleep(for: .milliseconds(600))  // milisaniyelik istekler de ikonda görünsün
            active -= 1
        }
    }

    nonisolated static func makeApp(keys: KeyStore, server: ProxyServer) -> some ApplicationProtocol {
        let router = Router()
        let forward: @Sendable (Request, BasicRequestContext) async throws -> Response = { req, _ in
            try await handle(req, keys: keys, server: server)
        }
        router.get("v1/**", use: forward)
        router.post("v1/**", use: forward)
        return Application(router: router, configuration: .init(address: .hostname("127.0.0.1", port: port)))
    }

    nonisolated static func handle(_ req: Request, keys: KeyStore, server: ProxyServer) async throws -> Response {
        // OpenAI SDK "Authorization: Bearer", Anthropic SDK "x-api-key" gönderir
        let bearer = req.headers[.authorization].flatMap { $0.hasPrefix("Bearer ") ? String($0.dropFirst(7)) : nil }
        let secret = bearer ?? req.headers[.init("x-api-key")!]
        guard let secret, await keys.validate(secret) else {
            return json(.unauthorized, req.uri.path.hasPrefix("/v1/messages")
                ? #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
                : #"{"error":{"message":"Incorrect API key provided.","type":"invalid_request_error","param":null,"code":"invalid_api_key"}}"#)
        }

        var upstream = HTTPClientRequest(url: ollama + req.uri.string)
        upstream.method = req.method == .get ? .GET : .POST
        if let contentType = req.headers[.contentType] { upstream.headers.add(name: "Content-Type", value: contentType) }
        upstream.body = .bytes(try await req.body.collect(upTo: 64 << 20))  // görsel (base64) istekleri için geniş limit

        await server.begin()
        let res: HTTPClientResponse
        do {
            // ponytail: deadline stream'i de keser; 1 saatlik tek cevap yerelde yeterli
            res = try await HTTPClient.shared.execute(upstream, timeout: .hours(1))
        } catch {
            await server.end()
            return json(.badGateway, #"{"error":{"message":"Ollama'ya ulaşılamıyor (127.0.0.1:11434). Ollama açık mı?","type":"api_error"}}"#)
        }
        var headers = HTTPFields()
        headers[.contentType] = res.headers.first(name: "content-type")
        // stream bitene (ya da istemci kopana) kadar istek "aktif" sayılır
        return Response(status: .init(code: Int(res.status.code)), headers: headers, body: ResponseBody { writer in
            defer { Task { await server.end() } }
            for try await chunk in res.body { try await writer.write(chunk) }
            try await writer.finish(nil)
        })
    }

    nonisolated static func json(_ status: HTTPResponse.Status, _ body: String) -> Response {
        Response(status: status, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(string: body)))
    }
}

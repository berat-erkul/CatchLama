/// Resmi dokümanlardaki örnekler, birebir (2026-10-14'te çekildi):
///   OpenAI     developers.openai.com/api/docs ("Write a short bedtime story" örneği, Responses API)
///   Anthropic  platform.claude.com/docs/en/get-started
///   Spring AI  docs.spring.io/spring-ai/reference/api/chat/openai-chat.html ("Sample Controller", 2.0)
/// Resmiden tek fark: model adı {{MODEL}} ile değişiyor; curl'de URL env'den geliyor (yoksa resmi URL).
/// SDK'lar base URL + key'i env'den okuduğu için gerçek sağlayıcıya geçmek = sadece env değiştirmek.
enum Template: String, CaseIterable, Identifiable {
    case openaiPython = "OpenAI · Python"
    case openaiJS = "OpenAI · JavaScript"
    case openaiJava = "OpenAI · Java"
    case openaiCurl = "OpenAI · curl"
    case anthropicPython = "Anthropic · Python"
    case anthropicTS = "Anthropic · TypeScript"
    case anthropicCurl = "Anthropic · curl"
    case springAI = "Spring AI 2.x"

    var id: String { rawValue }

    /// .env / terminal kısmı: yerel ile gerçek sağlayıcı arasındaki tek fark burada
    func env(model: String, key: String) -> String {
        let base = "http://localhost:\(ProxyServer.port)"
        switch self {
        case .openaiPython, .openaiJS, .openaiJava, .openaiCurl:
            return "export OPENAI_BASE_URL=\(base)/v1\nexport OPENAI_API_KEY=\(key)"
        case .anthropicPython, .anthropicTS, .anthropicCurl:
            return "export ANTHROPIC_BASE_URL=\(base)\nexport ANTHROPIC_API_KEY=\(key)"
        case .springAI:  // application.properties; resmi örneğe sadece base-url satırı eklendi
            return "spring.ai.openai.base-url=\(base)/v1\nspring.ai.openai.api-key=\(key)\nspring.ai.openai.chat.model=\(model)\nspring.ai.openai.chat.temperature=0.7"
        }
    }

    var switchHint: String {
        switch self {
        case .springAI: "Gerçek OpenAI'a geçmek için: base-url satırını sil, api-key'e gerçek key'i yaz."
        case .anthropicPython, .anthropicTS, .anthropicCurl: "Gerçek Anthropic'e geçmek için: ANTHROPIC_BASE_URL'i kaldır, gerçek key'i yaz."
        default: "Gerçek OpenAI'a geçmek için: OPENAI_BASE_URL'i kaldır, gerçek key'i yaz."
        }
    }

    func code(model: String) -> String {
        code.replacingOccurrences(of: "{{MODEL}}", with: model)
    }

    private var code: String {
        switch self {
        case .openaiPython: #"""
            from openai import OpenAI

            client = OpenAI()

            response = client.responses.create(model="{{MODEL}}", input="Write a short bedtime story about a unicorn.")

            print(response.output_text)
            """#
        case .openaiJS: #"""
            import OpenAI from "openai";
            const client = new OpenAI();

            const response = await client.responses.create({
              model: "{{MODEL}}",
              input: "Write a short bedtime story about a unicorn.",
            });

            console.log(response.output_text);
            """#
        case .openaiJava: #"""
            import com.openai.client.OpenAIClient;
            import com.openai.client.okhttp.OpenAIOkHttpClient;
            import com.openai.models.responses.Response;
            import com.openai.models.responses.ResponseCreateParams;

            public class PlatformOverviewExample {
              public static void main(String[] args) {
                OpenAIClient client = OpenAIOkHttpClient.fromEnv();

                ResponseCreateParams params =
                    ResponseCreateParams.builder().model("{{MODEL}}").input("Write a short bedtime story about a unicorn.").build();

                Response response = client.responses().create(params);
                response.output().stream()
                    .flatMap(item -> item.message().stream())
                    .flatMap(message -> message.content().stream())
                    .flatMap(content -> content.outputText().stream())
                    .forEach(outputText -> System.out.println(outputText.text()));
              }
            }
            """#
        case .openaiCurl: #"""
            curl ${OPENAI_BASE_URL:-https://api.openai.com/v1}/responses \
              -H "Content-Type: application/json" \
              -H "Authorization: Bearer $OPENAI_API_KEY" \
              -d '{
                "model": "{{MODEL}}",
                "input": "Write a short bedtime story about a unicorn."
              }'
            """#
        case .anthropicPython: #"""
            import anthropic

            client = anthropic.Anthropic()

            message = client.messages.create(
                model="{{MODEL}}",
                max_tokens=1000,
                messages=[
                    {
                        "role": "user",
                        "content": "What should I search for to find the latest developments in renewable energy?",
                    }
                ],
            )

            for block in message.content:
                if block.type == "text":
                    print(block.text)
            """#
        case .anthropicTS: #"""
            import Anthropic from "@anthropic-ai/sdk";

            const client = new Anthropic();

            const message = await client.messages.create({
              model: "{{MODEL}}",
              max_tokens: 1000,
              messages: [
                {
                  role: "user",
                  content: "What should I search for to find the latest developments in renewable energy?"
                }
              ]
            });

            for (const block of message.content) {
              if (block.type === "text") {
                console.log(block.text);
              }
            }
            """#
        case .anthropicCurl: #"""
            curl ${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/v1/messages \
              -H "content-type: application/json" \
              -H "x-api-key: $ANTHROPIC_API_KEY" \
              -H "anthropic-version: 2023-06-01" \
              -d '{
                "model": "{{MODEL}}",
                "max_tokens": 1000,
                "messages": [
                  {
                    "role": "user",
                    "content": "What should I search for to find the latest developments in renewable energy?"
                  }
                ]
              }'
            """#
        case .springAI: #"""
            @RestController
            public class ChatController {

                private final OpenAiChatModel chatModel;

                @Autowired
                public ChatController(OpenAiChatModel chatModel) {
                    this.chatModel = chatModel;
                }

                @GetMapping("/ai/generate")
                public Map<String,String> generate(@RequestParam(value = "message", defaultValue = "Tell me a joke") String message) {
                    return Map.of("generation", this.chatModel.call(message));
                }

                @GetMapping("/ai/generateStream")
            	public Flux<ChatResponse> generateStream(@RequestParam(value = "message", defaultValue = "Tell me a joke") String message) {
                    Prompt prompt = new Prompt(new UserMessage(message));
                    return this.chatModel.stream(prompt);
                }
            }
            """#
        }
    }
}

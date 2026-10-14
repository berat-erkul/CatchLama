import AppKit
import ServiceManagement
import SwiftUI

struct MenuView: View {
    let keys: KeyStore
    let proxy: ProxyServer

    @State private var models: [OllamaModel]?
    @State private var model = ""
    @State private var template = Template.openaiPython
    @State private var newKeyName = ""
    @State private var revealedKey: String?  // sadece oluşturulduğu an görünür
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            status
            Divider()
            modelList
            templateBox
            Divider()
            keySection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 460)
        .task { await reload() }
    }

    private var status: some View {
        HStack {
            Text("CatchLama").font(.headline)
            Spacer()
            dot(models != nil, models != nil ? "Ollama" : "Ollama kapalı")
            dot(proxy.error == nil, proxy.error == nil ? "Proxy :\(ProxyServer.port)" : "Proxy hata")
                .help(proxy.error ?? "http://localhost:\(ProxyServer.port)")
        }
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Modeller").font(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(models ?? []) { m in
                        HStack {
                            Text(m.name).lineLimit(1)
                            Spacer()
                            ForEach(m.capabilities ?? [], id: \.self) { cap in
                                Text(cap).font(.caption2)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(m.name == model ? Color.accentColor.opacity(0.25) : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                        .onTapGesture { model = m.name }
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }

    private var templateBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Şablon", selection: $template) {
                ForEach(Template.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)

            let m = model.isEmpty ? "<MODEL>" : model
            let env = template.env(model: m, key: revealedKey ?? "<API_KEY>")
            snippet(template == .springAI ? "application.properties" : "Ortam (.env / terminal)", env, height: template == .springAI ? 70 : 40)
            Text(template.switchHint + (revealedKey == nil ? " Key yer tutucu; yeni key oluşturunca buraya girer." : ""))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            snippet("Kod — resmi dokümandaki örnek, sadece model adı değişti", template.code(model: m), height: 170)
        }
    }

    private func snippet(_ title: String, _ text: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Kopyala") { copy(text) }.controlSize(.small)
            }
            ScrollView([.vertical, .horizontal]) {
                Text(text).font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: height)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("API Key'ler").font(.subheadline).foregroundStyle(.secondary)
            ForEach(keys.keys) { k in
                HStack {
                    Text(k.name)
                    Text(k.prefix + "…").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Text(k.lastUsedAt.map { "son: " + $0.formatted(.relative(presentation: .named)) } ?? "kullanılmadı")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(role: .destructive) { keys.revoke(k.id) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help("İptal et: bu key'le gelen istekler anında 401 alır")
                }
            }
            HStack {
                TextField("Key adı (ör. spring-ai-kurs)", text: $newKeyName)
                    .onSubmit(createKey)
                Button("Oluştur", action: createKey)
                    .disabled(newKeyName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let revealedKey {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bu key bir daha gösterilmeyecek, şimdi kopyala:").font(.caption)
                    HStack {
                        Text(revealedKey).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        Button("Kopyala") { copy(revealedKey) }
                    }
                }
                .padding(8)
                .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Login'de başlat", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, on in
                    do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                    catch { launchAtLogin = SMAppService.mainApp.status == .enabled }  // swift run'da (bundle yokken) çalışmaz
                }
            Spacer()
            Button("Yenile") { Task { await reload() } }
            Button("Çık") { NSApplication.shared.terminate(nil) }
        }
    }

    private func createKey() {
        let name = newKeyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        revealedKey = keys.create(name: name)
        newKeyName = ""
    }

    private func reload() async {
        models = await Ollama.models()
        if model.isEmpty || !(models ?? []).contains(where: { $0.name == model }) {
            model = models?.first?.name ?? ""
        }
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func dot(_ ok: Bool, _ label: String) -> some View {
        Label { Text(label).font(.caption) } icon: {
            Circle().fill(ok ? .green : .red).frame(width: 7, height: 7)
        }
    }
}

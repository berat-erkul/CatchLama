import AppKit
import ServiceManagement
import SwiftUI

/// Marka rengi: uygulama ikonundaki holografik tonlardan lila. Seçim ve birincil buton için.
private let brand = Color(red: 0.49, green: 0.36, blue: 0.98)
/// İkonun holografik geçişi; arayüzde sadece başlığın altındaki çizgide kullanılır.
private let holo = LinearGradient(
    colors: [Color(red: 0.96, green: 0.55, blue: 0.78), Color(red: 0.62, green: 0.52, blue: 0.98),
             Color(red: 0.45, green: 0.86, blue: 0.80), Color(red: 0.50, green: 0.75, blue: 0.97)],
    startPoint: .leading, endPoint: .trailing)
private let keyRowHeight: CGFloat = 46

/// Akış: soldan key ve model seç → sağda env (1) ve kod (2) hazır.
struct MenuView: View {
    let keys: KeyStore
    let proxy: ProxyServer

    @State private var models: [OllamaModel]?
    @AppStorage("model") private var model = ""
    @AppStorage("keyID") private var keyID = ""
    @AppStorage("template") private var template = Template.openaiPython
    @State private var newKeyName = ""
    @State private var confirmDelete: UUID?
    @State private var copied: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var selectedKey: APIKey? { keys.keys.first { $0.id.uuidString == keyID } }
    private var modelName: String { model.isEmpty ? "<MODEL>" : model }
    private var trimmedName: String { newKeyName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            header
            holo.frame(height: 2)
            HStack(spacing: 0) {
                sidebar.frame(width: 270)
                Divider()
                output
            }
            Divider()
            footer
        }
        .frame(width: 840, height: 560)
        .tint(brand)
        .background(CenterUnderStatusItem())
        .task { await reload() }
    }

    // MARK: Başlık

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 28, height: 28)
            Text("CatchLama").font(.system(size: 15, weight: .semibold))
            Spacer()
            if proxy.active > 0 {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("İstek işleniyor")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            status(models != nil, models != nil ? "Ollama açık" : "Ollama kapalı")
            status(proxy.error == nil, proxy.error == nil ? "localhost:\(ProxyServer.port)" : "Proxy başlamadı")
                .help(proxy.error ?? "SDK'ların bağlandığı adres")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func status(_ ok: Bool, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(ok ? Color.green : Color.red).frame(width: 7, height: 7)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    // MARK: Sol panel: key'ler ve modeller

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Key'ler", count: keys.keys.count)
            keyList
            newKeyField
            Divider().padding(.vertical, 6)
            sectionTitle("Modeller", count: models?.count ?? 0)
            modelList
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.primary.opacity(0.025))
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            if count > 0 { Text("\(count)").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private var keyList: some View {
        Group {
            if keys.keys.isEmpty {
                Text("Henüz key yok. Her proje için ayrı bir key oluştur.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else {
                let visible = CGFloat(min(keys.keys.count, 3))  // 3'ten fazlası kaydırılır
                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(keys.keys) { keyRow($0).id($0.id) }
                        }
                    }
                    .frame(height: visible * keyRowHeight + (visible - 1) * 2)
                    .onAppear { scroller.scrollTo(UUID(uuidString: keyID)) }
                    .onChange(of: keyID) { _, id in
                        withAnimation { scroller.scrollTo(UUID(uuidString: id)) }
                    }
                }
            }
        }
    }

    private func keyRow(_ k: APIKey) -> some View {
        let selected = k.id.uuidString == keyID
        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(k.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(k.lastUsedAt.map { $0.formatted(.relative(presentation: .named)) } ?? "kullanılmadı")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(k.secret ?? "\(k.prefix)… tam hali kayıtlı değil")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(k.secret == nil ? "v0.1'de oluşturuldu, tam hali saklanmadı. Sil ve yenisini oluştur." : "")
            }
            if let secret = k.secret {
                copyButton(secret, id: "key-\(k.id)", iconOnly: true)
            }
            if confirmDelete == k.id {
                Button("Sil") {
                    keys.revoke(k.id)
                    confirmDelete = nil
                    if selected { keyID = "" }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            } else {
                Button { confirmDelete = k.id } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Sil: bu key'le gelen istekler 401 alır")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: keyRowHeight)
        .background(selected ? brand.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onTapGesture {
            keyID = k.id.uuidString
            confirmDelete = nil
        }
        .accessibilityAddTraits(.isButton)
    }

    private var newKeyField: some View {
        HStack(spacing: 6) {
            TextField("Yeni key adı", text: $newKeyName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(createKey)
            Button("Oluştur", action: createKey)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty)
        }
    }

    private var modelList: some View {
        Group {
            if let models {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(models) { modelRow($0) }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ollama'ya ulaşılamıyor.").font(.callout)
                    Text("Ollama uygulamasını aç, sonra Yenile'ye bas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func modelRow(_ m: OllamaModel) -> some View {
        Button { model = m.name } label: {
            HStack(spacing: 6) {
                Text(m.name).font(.system(size: 12.5)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 4)
                ForEach(capabilityIcons(m), id: \.symbol) { cap in
                    Image(systemName: cap.symbol)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .help(cap.label)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(m.name == model ? brand.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func capabilityIcons(_ m: OllamaModel) -> [(symbol: String, label: String)] {
        let caps = m.capabilities ?? []
        return [("tools", "wrench.and.screwdriver", "Tool calling"), ("vision", "eye", "Görsel girdi"),
                ("thinking", "brain", "Thinking"), ("embedding", "square.stack.3d.up", "Embedding")]
            .filter { caps.contains($0.0) }
            .map { (symbol: $0.1, label: $0.2) }
    }

    // MARK: Sağ panel: env + kod

    private var output: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Şablon", selection: $template) {
                ForEach(Template.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .fixedSize()

            step(1, template == .springAI ? "application.properties dosyasına ekle" : "Terminale yapıştır",
                 template.env(model: modelName, key: selectedKey?.secret ?? "<API_KEY>"), id: "env")

            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            step(2, template == .springAI ? "Controller'ı projene ekle" : "Kodu olduğu gibi çalıştır",
                 template.code(model: modelName), id: "code", grows: true)
        }
        .padding(16)
    }

    private var hint: String {
        guard let key = selectedKey else { return "Soldan bir key seç; 1. adımdaki satıra o girer." }
        guard key.secret != nil else { return "Bu key'in tam hali kayıtlı değil. Yeni bir key oluştur ve onu seç." }
        return template.switchHint
    }

    private func step(_ n: Int, _ title: String, _ text: String, id: String, grows: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "\(n).circle.fill").foregroundStyle(brand)
                Text(title).font(.system(size: 12.5, weight: .medium))
                Spacer()
                copyButton(text, id: id)
            }
            Group {
                if grows {
                    ScrollView([.vertical, .horizontal]) { codeText(text).fixedSize() }  // uzun satır yatay kayar
                        .defaultScrollAnchor(.topLeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    codeText(text)  // env kısa: gerekirse satır kırar, key hep tamamen görünür
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
        }
    }

    private func codeText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
    }

    @ViewBuilder
    private func copyButton(_ text: String, id: String, iconOnly: Bool = false) -> some View {
        let done = copied == id
        let button = Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = id
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                if copied == id { copied = nil }
            }
        } label: {
            if iconOnly {
                Image(systemName: done ? "checkmark" : "doc.on.doc")
            } else {
                Label(done ? "Kopyalandı" : "Kopyala", systemImage: done ? "checkmark" : "doc.on.doc")
            }
        }
        if iconOnly {
            button.buttonStyle(.borderless).foregroundStyle(done ? Color.primary : Color.secondary).help("Key'i kopyala")
        } else {
            button.buttonStyle(.bordered).controlSize(.small)
        }
    }

    // MARK: Alt çubuk

    private var footer: some View {
        HStack {
            Toggle("Login'de başlat", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, on in
                    do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                    catch { launchAtLogin = SMAppService.mainApp.status == .enabled }  // swift run'da (bundle yokken) çalışmaz
                }
            Spacer()
            Button { Task { await reload() } } label: { Label("Yenile", systemImage: "arrow.clockwise") }
            Button("Çık") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: İşler

    private func createKey() {
        guard !trimmedName.isEmpty else { return }
        keyID = keys.create(name: trimmedName).id.uuidString  // yeni key seçili gelir, şablona girer
        newKeyName = ""
    }

    private func reload() async {
        models = await Ollama.models()
        if !(models ?? []).contains(where: { $0.name == model }) {
            model = models?.first?.name ?? ""
        }
        if selectedKey == nil, let first = keys.keys.last(where: { $0.secret != nil }) {
            keyID = first.id.uuidString
        }
    }
}

/// MenuBarExtra pencerenin yerini ayarlamaya izin vermiyor. Pencere her açıldığında
/// (key olduğunda) tıklanan ikonun altına ortalar; ekrana sığmazsa kenara yaslar.
private struct CenterUnderStatusItem: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Probe: NSView {
        private var token: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            guard let window else { return }
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.center() }
            }
            center()
        }

        private func center() {
            guard let window else { return }
            let mouse = NSEvent.mouseLocation  // pencere ikona tıklanınca açılıyor: imleç ikonun üstünde
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? window.screen else { return }
            let x = centeredX(iconX: mouse.x, width: window.frame.width, screen: screen.visibleFrame)
            window.setFrameOrigin(NSPoint(x: x, y: window.frame.minY))
        }
    }
}

/// Pencerenin x'i: ikonun ortasına hizalı, ekrandan taşarsa `margin` kadar içeride.
func centeredX(iconX: CGFloat, width: CGFloat, screen: CGRect, margin: CGFloat = 8) -> CGFloat {
    min(max(iconX - width / 2, screen.minX + margin), screen.maxX - width - margin)
}

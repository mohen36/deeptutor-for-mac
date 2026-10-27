import AppKit
import WebKit
import Foundation

final class DesktopApp: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow!
    private var homeView: NSView!
    private var statusField: NSTextField!
    private var installButton: NSButton!
    private var startButton: NSButton!
    private var webView: WKWebView?
    private var polling: Timer?
    private var pollCount = 0
    private var launchedHere = false
    private var busy = false

    private let frontend = URL(string: "http://127.0.0.1:3782/")!
    private let runtimeHome: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("DeepTutor-for-Mac", isDirectory: true).appendingPathComponent("runtime", isDirectory: true)
    }()

    private var cliPath: String { runtimeHome.appendingPathComponent(".venv/bin/deeptutor").path }
    private var pythonPath: String { runtimeHome.appendingPathComponent(".venv/bin/python").path }
    private let executableDirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "DeepTutor for Mac"
        window.minSize = NSSize(width: 760, height: 530)
        window.center()
        window.delegate = self
        showWelcome()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if FileManager.default.isExecutableFile(atPath: cliPath) {
            startDeepTutor()
        } else {
            status("首次使用：请点击「安装核心」。首次安装需要网络连接。")
        }
    }

    private func makeMenu() {
        let main = NSMenu()
        let appMenuItem = NSMenuItem()
        main.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 DeepTutor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        let edit = NSMenuItem()
        main.addItem(edit)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        NSApp.mainMenu = main
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = .labelColor
        field.alignment = .center
        field.maximumNumberOfLines = 0
        field.lineBreakMode = .byWordWrapping
        return field
    }

    private func showWelcome() {
        let container = NSView(frame: window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 1080, height: 740))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        let emoji = label("🎓", size: 72)
        let title = label("DeepTutor for Mac", size: 31, weight: .bold)
        let sub = label("独立桌面窗口 · 自动管理本地学习服务", size: 15)
        sub.textColor = .secondaryLabelColor
        let statusView = label("正在准备…", size: 14)
        statusField = statusView
        statusView.preferredMaxLayoutWidth = 580
        let install = NSButton(title: "安装 / 更新核心", target: self, action: #selector(installTapped))
        installButton = install
        install.bezelStyle = .rounded
        install.controlSize = .large
        let start = NSButton(title: "启动 / 重试", target: self, action: #selector(startTapped))
        startButton = start
        start.bezelStyle = .rounded
        start.controlSize = .large
        let buttons = NSStackView(views: [install, start])
        buttons.orientation = .horizontal
        buttons.spacing = 16
        let arrangedViews: [NSView] = [emoji, title, sub, statusView, buttons]
        for item in arrangedViews { stack.addArrangedSubview(item) }
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 0.85),
            statusView.widthAnchor.constraint(equalToConstant: 580)
        ])
        homeView = container
        window.contentView = container
    }

    private func status(_ message: String) {
        DispatchQueue.main.async { [weak self] in self?.statusField?.stringValue = message }
    }

    private func setBusy(_ value: Bool) {
        busy = value
        installButton.isEnabled = !value
        startButton.isEnabled = !value
    }

    private func executable(_ names: [String]) -> String? {
        for name in names {
            for dir in executableDirs {
                let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name).path
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    private func run(_ program: String, _ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: program)
        task.arguments = arguments
        task.currentDirectoryURL = runtimeHome
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = executableDirs.joined(separator: ":") + ":" + (env["PATH"] ?? "")
        env["PYTHONUNBUFFERED"] = "1"
        env["PIP_DISABLE_PIP_VERSION_CHECK"] = "1"
        task.environment = env
        let output = Pipe()
        task.standardOutput = output
        task.standardError = output
        try task.run()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let message = String(data: result, encoding: .utf8) ?? ""
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "DeepTutor", code: Int(task.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "命令失败：\(message.suffix(1200))"])
        }
        return message
    }

    private func runLauncher(_ arguments: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        task.arguments = arguments
        task.currentDirectoryURL = runtimeHome
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = executableDirs.joined(separator: ":") + ":" + (env["PATH"] ?? "")
        task.environment = env
        // A detached backend may retain file descriptors. Avoid waiting on a pipe's EOF.
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw problem("DeepTutor 启动器退出码 \(task.terminationStatus)。可以在终端执行 deeptutor doctor 检查配置。")
        }
    }

    @objc private func installTapped() {
        guard !busy else { return }
        setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let manager = FileManager.default
                try manager.createDirectory(at: self.runtimeHome, withIntermediateDirectories: true)
                guard let node = self.executable(["node"]) else { throw self.problem("没有找到 Node.js。请运行 brew install node") }
                let version = try self.run(node, ["-p", "Number(process.versions.node.split('.')[0]) >= 20"])
                guard version.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else { throw self.problem("需要 Node.js 20 或更高版本") }
                guard let python = self.executable(["python3.12", "python3.13", "python3.11", "python3.14"]) else { throw self.problem("没有找到 Python 3.11–3.14。请运行 brew install python@3.12") }
                if !manager.isExecutableFile(atPath: self.pythonPath) {
                    self.status("正在创建独立 Python 环境…")
                    _ = try self.run(python, ["-m", "venv", ".venv"])
                }
                self.status("正在更新安装工具…")
                _ = try self.run(self.pythonPath, ["-m", "pip", "install", "--upgrade", "pip"])
                self.status("正在安装 DeepTutor 官方核心；首次下载可能需要几分钟…")
                _ = try self.run(self.pythonPath, ["-m", "pip", "install", "--upgrade", "deeptutor"])
                self.status("正在初始化学习空间…")
                _ = try self.run(self.cliPath, ["init", "--non-interactive"])
                DispatchQueue.main.async {
                    self.setBusy(false)
                    self.startDeepTutor()
                }
            } catch {
                self.status("安装未完成：\(error.localizedDescription)")
                DispatchQueue.main.async { self.setBusy(false) }
            }
        }
    }

    private func problem(_ message: String) -> NSError {
        NSError(domain: "DeepTutor", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @objc private func startTapped() { startDeepTutor() }

    private func startDeepTutor() {
        guard !busy else { return }
        guard FileManager.default.isExecutableFile(atPath: cliPath) else {
            status("请先点击「安装 / 更新核心」。")
            return
        }
        setBusy(true)
        status("正在启动 DeepTutor…")
        // Avoid attaching to an unrelated process on a fixed port.
        checkServer { [weak self] occupied in
            guard let self = self else { return }
            if occupied {
                self.status("端口 3782 已被其他程序使用。请先退出旧的 DeepTutor，再点击重试。")
                self.setBusy(false)
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.runLauncher(["start", "--detach", "--no-browser"])
                    DispatchQueue.main.async {
                        self.launchedHere = true
                        self.pollCount = 0
                        self.polling?.invalidate()
                        self.polling = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.pollServer() }
                    }
                } catch {
                    self.status("启动失败：\(error.localizedDescription)")
                    DispatchQueue.main.async { self.setBusy(false) }
                }
            }
        }
    }

    private func checkServer(_ completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: frontend)
        request.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async { completion(response != nil) }
        }.resume()
    }

    private func pollServer() {
        pollCount += 1
        if pollCount > 80 {
            polling?.invalidate()
            status("启动超时。请检查服务端口 3782/8001 是否被占用，或点击重试。")
            setBusy(false)
            return
        }
        checkServer { [weak self] ready in
            guard let self = self, ready else { return }
            self.polling?.invalidate()
            self.setBusy(false)
            self.showBrowser()
        }
    }

    private func showBrowser() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let browser = WKWebView(frame: window.contentView?.bounds ?? .zero, configuration: config)
        browser.navigationDelegate = self
        browser.uiDelegate = self
        browser.autoresizingMask = [.width, .height]
        browser.load(URLRequest(url: frontend))
        webView = browser
        window.contentView = browser
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           url.host != "127.0.0.1" || url.port != 3782 {
            if let url = navigationAction.request.url, ["https", "http"].contains(url.scheme ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, ["https", "http"].contains(url.scheme ?? "") {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        polling?.invalidate()
        if launchedHere {
            // The CLI owns a detached service. Stop only a service started by this window.
            try? runLauncher(["stop"])
        }
    }
}

let application = NSApplication.shared
let delegate = DesktopApp()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()

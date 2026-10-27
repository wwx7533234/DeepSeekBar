import AppKit
import WebKit

/// DeepSeek 官方网页授权：弹出 WKWebView 让用户扫码/验证码登录，
/// 注入 JS hook 捕获带 Authorization 的请求，取出登录 token。
/// 登录态持久化（WKWebsiteDataStore.default），token 存钥匙串。
@MainActor
final class WebAuthController: NSObject, WKNavigationDelegate {
    static let shared = WebAuthController()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var pollTask: Task<Void, Never>?
    private var onToken: ((String) -> Void)?

    /// 注入脚本：hook fetch 与 XMLHttpRequest，捕获 Authorization / 任意含 token 的 header。
    /// 注意：header 名匹配必须含 "authorization"（否则 XHR 的 Authorization 会漏掉）；
    /// 兜底记录长度 > 20 的非数字 header 值（防自定义 token 头）。
    private static let injectionScript = """
    (function(){if(window.__dsbHooked)return;window.__dsbHooked=1;window.__dsbLog=[];function ok(k){var s=String(k).toLowerCase();return s==="authorization"||s.indexOf("token")>=0}function push(v){try{var s=String(v);if(s.length>16&&!/^\\d+$/.test(s)){window.__dsbLog.push(s);if(window.__dsbLog.length>40)window.__dsbLog.shift()}}catch(e){}}var of=window.fetch;window.fetch=function(){var o=arguments[1]||{},h=o.headers||{};try{if(h&&h.forEach){h.forEach(function(v,k){if(ok(k))push(v)})}else{for(var k in h){if(ok(k))push(h[k])}}}catch(e){}return of.apply(this,arguments)};var oo=XMLHttpRequest.prototype.open,os=XMLHttpRequest.prototype.setRequestHeader;XMLHttpRequest.prototype.open=function(){try{this.__h={}}catch(e){}return oo.apply(this,arguments)};XMLHttpRequest.prototype.setRequestHeader=function(k,v){try{if(ok(k))push(v)}catch(e){}return os.apply(this,arguments)};})();
    """

    /// 弹出登录窗口（已存在则前置）
    func presentLogin(onToken: @escaping (String) -> Void) {
        print("[WebAuth] presentLogin")
        self.onToken = onToken
        if let w = window, let web = webView {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            web.reload()
            print("[WebAuth] 窗口已存在，前置并刷新")
            startPolling()
            return
        }

        let config = WKWebViewConfiguration()
        let script = WKUserScript(source: Self.injectionScript,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.websiteDataStore = .default() // 持久化登录态，登录一次长期有效

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        webView = web

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        win.title = "DeepSeek 官方用量授权"
        win.isReleasedWhenClosed = false
        win.level = .floating // 浮动层级，避免被全屏窗口挡住
        win.contentView = web
        window = win
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        web.load(URLRequest(url: PlatformWeb.usageURL))
        print("[WebAuth] 授权窗口已弹出，开始轮询 token")
        startPolling()
    }

    func hide() {
        print("[WebAuth] hide 授权窗口")
        window?.orderOut(nil)
        pollTask?.cancel()
    }

    // MARK: - 轮询抓 token

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var lastSeen: String?
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let self, self.webView != nil else { return }
                await self.checkLog(lastSeen: &lastSeen)
            }
        }
    }

    private func checkLog(lastSeen: inout String?) async {
        let js = "window.__dsbLog ? JSON.stringify(window.__dsbLog) : '[]'"
        guard let result = await evaluate(js) else {
            print("[WebAuth] evaluate 失败/空")
            return
        }
        guard let data = result.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String],
              let newest = arr.last, newest != lastSeen else { return }
        lastSeen = newest
        print("[WebAuth] 捕获到 header: \(newest.prefix(24))… (共\(newest.count)字符)")

        var token = newest.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") {
            token = String(token.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard token.count >= 16 else {
            print("[WebAuth] token 太短(\(token.count))，忽略")
            return
        }

        hide()
        print("[WebAuth] ✅ 抓到 token，回调")
        onToken?(token)
    }

    private func evaluate(_ js: String) async -> String? {
        await withCheckedContinuation { cont in
            webView?.evaluateJavaScript(js) { result, _ in
                if let s = result as? String { cont.resume(returning: s) }
                else if let o = result { cont.resume(returning: String(describing: o)) }
                else { cont.resume(returning: nil) }
            }
        }
    }
}

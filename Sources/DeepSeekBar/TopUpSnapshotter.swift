import AppKit
import WebKit

/// 调试用：在锁屏 / 无显示器环境下把官方充值页渲染成 PNG，
/// 用于确认 380pt 面板宽度下页面是否可用。正式功能不依赖此类。
@MainActor
final class TopUpSnapshotter: NSObject, WKNavigationDelegate {
    static let shared = TopUpSnapshotter()

    private var webView: WKWebView?
    private var window: NSWindow?
    private var outputPath: String?
    private var captured = false

    func capture(width: CGFloat, height: CGFloat, to path: String) {
        print("[TopUpSnapshot] capture \(Int(width))x\(Int(height))")
        outputPath = path
        captured = false

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: config)
        web.navigationDelegate = self

        let win = NSWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.contentView = web
        win.orderBack(nil)

        self.webView = web
        self.window = win
        web.load(URLRequest(url: PlatformWeb.topUpURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[TopUpSnapshot] didFinish \(webView.url?.absoluteString ?? "nil")")
        guard !captured else { return }
        captured = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let config = WKSnapshotConfiguration()
            config.rect = NSRect(x: 0, y: 0, width: webView.bounds.width, height: webView.bounds.height)
            webView.takeSnapshot(with: config) { image, error in
                guard let image,
                      let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    print("[TopUpSnapshot] failed: \(error?.localizedDescription ?? "no image")")
                    NSApp.terminate(nil)
                    return
                }
                try? png.write(to: URL(fileURLWithPath: self.outputPath ?? "/tmp/topup.png"))
                print("[TopUpSnapshot] saved \(Int(image.size.width))x\(Int(image.size.height))")
                NSApp.terminate(nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[TopUpSnapshot] didFail \(error.localizedDescription)")
        NSApp.terminate(nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[TopUpSnapshot] didFailProvisional \(error.localizedDescription)")
        NSApp.terminate(nil)
    }
}

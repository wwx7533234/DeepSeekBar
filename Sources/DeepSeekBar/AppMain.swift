import SwiftUI
import AppKit

/// 调试用：--window 参数启动时弹出一个无边框预览窗口（便于截图/验证 UI）。
/// 注：SwiftUI SceneBuilder 里动态 if + WindowGroup 会触发本工具链编译器 bug，
/// 因此预览窗口用 NSWindow + NSHostingController 手动创建。
/// 其他调试参数：--settings 打开设置页，--dark / --light 固定明暗外观，
/// --snapshot <png> 无窗口渲染一张面板截图（锁屏/无显示器时也可用）。
final class PreviewWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--dark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else if CommandLine.arguments.contains("--light") {
            NSApp.appearance = NSAppearance(named: .aqua)
        }

        if let index = CommandLine.arguments.firstIndex(of: "--snapshot-topup") {
            let path = index + 1 < CommandLine.arguments.count
                ? CommandLine.arguments[index + 1]
                : "/tmp/topup.png"
            TopUpSnapshotter.shared.capture(width: 380, height: 600, to: path)
            return
        }

        if let index = CommandLine.arguments.firstIndex(of: "--snapshot-view"),
           index + 1 < CommandLine.arguments.count,
           let state = AppDelegate.sharedState {
            let path = CommandLine.arguments[index + 1]
            ViewSnapshotter.capture(page: Self.requestedPage, state: state, width: 380, height: 620, to: path)
            return
        }

        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"),
           index + 1 < CommandLine.arguments.count,
           let state = AppDelegate.sharedState {
            let path = CommandLine.arguments[index + 1]
            // 等本地 mock / 官方接口完成首轮加载再渲染
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                Task { @MainActor in
                    Self.renderSnapshot(state: state, to: path)
                    NSApp.terminate(nil)
                }
            }
            return
        }

        guard CommandLine.arguments.contains("--window"),
              let state = AppDelegate.sharedState else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let page = Self.requestedPage
            let root = ContentView(initialPage: page)
                .environmentObject(state)
                .background(DS.background)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DS.border.opacity(0.9), lineWidth: 0.8)
                )

            let host = NSHostingController(rootView: root)
            host.sizingOptions = [.preferredContentSize]

            let window = PreviewWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 620),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "DeepSeekBar 预览"
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .floating
            window.contentViewController = host
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)

        }
    }

    private static var requestedPage: ContentPage {
        if CommandLine.arguments.contains("--settings") { return .settings }
        if CommandLine.arguments.contains("--recharge") { return .recharge }
        if CommandLine.arguments.contains("--api") { return .apiKeys }
        return .main
    }

    @MainActor
    private static func renderSnapshot(state: AppState, to path: String) {
        let page = requestedPage
        let scheme: ColorScheme = CommandLine.arguments.contains("--dark") ? .dark : .light

        let root = ContentView(initialPage: page)
            .environmentObject(state)
            .environment(\.colorScheme, scheme)
            .frame(width: 380)
            .background(DS.background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DS.border.opacity(0.9), lineWidth: 0.8)
            )

        let renderer = ImageRenderer(content: root)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("[Snapshot] failed")
            return
        }

        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("[Snapshot] \(Int(image.size.width))x\(Int(image.size.height)) -> \(path)")
        } catch {
            print("[Snapshot] write failed: \(error.localizedDescription)")
        }
    }
}

@main
struct DeepSeekBarApp: App {
    @StateObject private var appState: AppState
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        AppDelegate.sharedState = state
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appState)
        } label: {
            Label(appState.menuBarTitle, systemImage: "chart.line.uptrend.xyaxis")
        }
        .menuBarExtraStyle(.window)
    }
}

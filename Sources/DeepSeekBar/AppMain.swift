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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DS.rule, lineWidth: 1)
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DS.rule, lineWidth: 1)
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

/// 菜单栏图标：把货币符号当作标记画成模板图，随菜单栏明暗自动反色。
/// 不用 chart.bar 这类图标，避免被看成信号强度。
enum MenuBarMark {
    private static var cache: [String: NSImage] = [:]

    /// 按样式取图，带缓存，避免每次刷新都重绘
    static func icon(for style: MenuBarIconStyle) -> NSImage? {
        switch style {
        case .amount:
            return nil
        case .standard:
            if let cached = cache["standard"] { return cached }
            guard let image = MenuBarMark.symbol() else { return nil }
            cache["standard"] = image
            return image
        }
    }

    /// 常规图标：DeepSeek 的鲸鱼意象（系统里最接近的鱼形符号），
    /// 模板渲染，随菜单栏明暗反色；只画图标，不带金额。
    static func symbol() -> NSImage? {
        // DSBAR_SYMBOL 可在调试时替换符号名，用于比较不同图标
        let name = ProcessInfo.processInfo.environment["DSBAR_SYMBOL"] ?? "fish"
        guard let base = NSImage(systemSymbolName: name,
                                 accessibilityDescription: "DeepSeekBar") else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let image = base.withSymbolConfiguration(config) else { return base }
        image.isTemplate = true
        return image
    }

}

/// 菜单栏：图标 + 金额，样式由设置决定
struct MenuBarLabel: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 4) {
            if let icon = MenuBarMark.icon(for: state.menuBarIconStyle) {
                Image(nsImage: icon)
            }
            if !state.menuBarText.isEmpty {
                Text(state.menuBarText)
                    .monospacedDigit()
            }
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
            MenuBarLabel(state: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

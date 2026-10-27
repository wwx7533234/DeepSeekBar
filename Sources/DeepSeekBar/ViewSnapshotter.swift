import AppKit
import SwiftUI

/// 调试用：用 NSHostingView + cacheDisplay 渲染整页（可包含 ScrollView 内容）。
/// 正式功能不依赖此类。
@MainActor
final class ViewSnapshotter {
    static func capture(page: ContentPage, state: AppState, width: CGFloat, height: CGFloat, to path: String) {
        print("[ViewSnapshot] capture \(page) \(Int(width))x\(Int(height))")

        let root = ContentView(initialPage: page)
            .environmentObject(state)
            .frame(width: width)
            .background(DS.background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DS.border.opacity(0.9), lineWidth: 0.8)
            )

        let host = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = host
        window.orderFrontRegardless()

        host.view.layoutSubtreeIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            host.view.layoutSubtreeIfNeeded()
            host.view.displayIfNeeded()

            guard let rep = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) else {
                print("[ViewSnapshot] no bitmap rep")
                NSApp.terminate(nil)
                return
            }
            host.view.cacheDisplay(in: host.view.bounds, to: rep)

            guard let png = rep.representation(using: .png, properties: [:]) else {
                print("[ViewSnapshot] no png")
                NSApp.terminate(nil)
                return
            }

            try? png.write(to: URL(fileURLWithPath: path))
            print("[ViewSnapshot] saved \(rep.pixelsWide)x\(rep.pixelsHigh) -> \(path)")
            NSApp.terminate(nil)
        }
    }
}

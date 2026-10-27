// 生成 macOS App 图标（品牌渐变圆角方块 + DS 字样）
// 用法: swift scripts/generate_icon.swift <输出目录(iconset)>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

let colors = [
    NSColor(srgbRed: 0x25 / 255.0, green: 0x38 / 255.0, blue: 0xC8 / 255.0, alpha: 1),
    NSColor(srgbRed: 0x4D / 255.0, green: 0x6B / 255.0, blue: 0xFE / 255.0, alpha: 1),
    NSColor(srgbRed: 0x84 / 255.0, green: 0x96 / 255.0, blue: 0xFF / 255.0, alpha: 1),
]

for s in sizes {
    let px = CGFloat(s.px)
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: px, height: px)
    let radius = px * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGradient(colors: colors)?.draw(in: path, angle: -45)

    // 左上角柔光，让大面积渐变不呆板
    let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.20),
        NSColor.white.withAlphaComponent(0.0)
    ])
    glow?.draw(in: path, relativeCenterPosition: NSPoint(x: -0.42, y: 0.48))

    // 内侧高光描边
    path.lineWidth = max(1, px * 0.007)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    path.stroke()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = px * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -px * 0.012)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: px * 0.38, weight: .heavy),
        .foregroundColor: NSColor.white,
        .shadow: shadow
    ]
    let str = NSAttributedString(string: "DS", attributes: attrs)
    let size = str.size()
    str.draw(at: NSPoint(
        x: (px - size.width) / 2,
        y: (px - size.height) / 2 - px * 0.02
    ))
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(s.name)"))
}
print("icons generated in \(outDir)")

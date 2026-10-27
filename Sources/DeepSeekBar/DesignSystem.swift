import SwiftUI
import AppKit

/// 设计系统：品牌色、表面色、卡片/按钮/胶囊等可复用组件。
/// 所有表面色都是动态色，自动跟随系统浅色 / 深色模式。
enum DS {
    // MARK: - 品牌色

    static let brand      = Color(hex: 0x4D6BFE)
    static let brandDeep  = Color(hex: 0x2B3FD0)
    static let brandLight = Color(hex: 0x8FA6FF)
    static let violet     = Color(hex: 0x8B5CF6)
    static let teal       = Color(hex: 0x14B8A6)
    static let green      = Color(hex: 0x22C55E)
    static let amber      = Color(hex: 0xF59E0B)
    static let red        = Color(hex: 0xEF4444)

    // MARK: - 自适应表面色

    static let background   = dynamic(0xF4F6FB, 0x0D0F14)
    static let card         = dynamic(0xFFFFFF, 0x171A21)
    static let cardSoft     = dynamic(0xF6F8FD, 0x1F232C)
    static let cardHover    = dynamic(0xEEF2FF, 0x252B37)
    static let border       = dynamic(0xE7EAF2, 0x2A2F3A)
    static let divider      = dynamic(0xEEF1F7, 0x262B35)

    static let textPrimary   = dynamic(0x101828, 0xF3F5F9)
    static let textSecondary = dynamic(0x667085, 0x98A2B3)
    static let textTertiary  = dynamic(0x98A2B3, 0x6C7688)

    // MARK: - 渐变

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x2538C8), Color(hex: 0x4D6BFE), Color(hex: 0x8496FF)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let barGradient = LinearGradient(
        colors: [Color(hex: 0x4D6BFE), Color(hex: 0x8B5CF6)],
        startPoint: .bottom,
        endPoint: .top
    )

    static let radius: CGFloat = 18

    // MARK: - 动态色工具

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

// MARK: - 颜色扩展

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - 卡片

struct DSCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DS.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DS.border, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.045), radius: 14, x: 0, y: 5)
    }
}

extension View {
    func dsCard(padding: CGFloat = 14, radius: CGFloat = DS.radius) -> some View {
        modifier(DSCardModifier(padding: padding, radius: radius))
    }
}

// MARK: - 状态胶囊

struct DSPill: View {
    let text: String
    var color: Color = DS.brand
    var icon: String?
    var showsDot: Bool = true
    var size: CGFloat = 9.5

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size - 0.5, weight: .bold))
            } else if showsDot {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .shadow(color: color.opacity(0.55), radius: 3)
            }
            Text(text)
                .font(.system(size: size, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.11)))
        .overlay(Capsule().strokeBorder(color.opacity(0.12), lineWidth: 0.5))
    }
}

// MARK: - 图标按钮

struct DSIconButton: View {
    let systemName: String
    var help: String = ""
    var tint: Color = DS.textSecondary
    var hoverTint: Color = DS.textPrimary
    var hoverFill: Color = DS.cardSoft
    var size: CGFloat = 28
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(hovering ? hoverTint : tint)
                .frame(width: size, height: size)
                .background(Circle().fill(hovering ? hoverFill : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - 按钮样式

struct DSPrimaryButtonStyle: ButtonStyle {
    var color: Color = DS.brand
    var expands: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, expands ? 12 : 11)
            .padding(.vertical, 6)
            .frame(maxWidth: expands ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0 : 0.24), radius: 7, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(configuration.isPressed ? DS.cardHover : DS.cardSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(DS.border, lineWidth: 0.8)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 品牌标识

struct DSLogo: View {
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(DS.heroGradient)
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
            Text("DS")
                .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.14), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: DS.brand.opacity(0.32), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 通用小组件

struct DSSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DS.textPrimary)
    }
}

struct DSDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.divider)
            .frame(height: 1)
    }
}

import SwiftUI
import AppKit

/// 设计系统 · 刻度（Scale）
///
/// 一块连续的仪表面板，而不是一叠卡片：
/// - 没有渐变、没有投影、没有玻璃拟态、没有圆角容器、没有图标底砖。
/// - 层级由排版和发丝线建立：等宽小标签 / 表格数字 / 1px 分隔线。
/// - 只有一处信号色，出现即代表「当前」；其余全部是纸面与墨色。
enum DS {
    // MARK: - 墨色与纸面

    static let ground    = dynamic(0xF3F1EC, 0x0E0F11)   // 纸 / 石墨
    static let raise     = dynamic(0xFBFAF7, 0x141518)   // 略微抬起的表面
    static let tick      = dynamic(0xEAE6DE, 0x1B1D21)   // 刻度底色
    static let ink       = dynamic(0x17181B, 0xEDEDE8)   // 主文字
    static let ink2      = dynamic(0x4A4B51, 0xB4B5BA)   // 次文字
    static let ink3      = dynamic(0x6B6C72, 0x8C8D94)   // 微标签
    static let rule      = dynamic(0xDBD6CD, 0x25272B)   // 发丝线
    static let ruleSoft  = dynamic(0xE8E4DC, 0x1C1E22)   // 更轻的线

    // MARK: - 信号色（全屏唯一强调色）

    static let signal    = dynamic(0x2A3AC8, 0x97A3FF)
    static let ok        = dynamic(0x2E7A4E, 0x74CE93)
    static let warn      = dynamic(0xA9660F, 0xDFA257)
    static let err       = dynamic(0xB03A32, 0xE07B72)

    // MARK: - 旧接口兼容（其余页面沿用，取值已换到新色板）

    static let brand      = signal
    static let brandDeep  = signal
    static let brandLight = signal.opacity(0.55)
    static let violet     = dynamic(0x5B4B8A, 0xA99BD8)
    static let teal       = dynamic(0x2F6E6A, 0x74C4BE)
    static let green      = ok
    static let amber      = warn
    static let red        = err

    static let background   = ground
    static let card         = raise
    static let cardSoft     = tick
    static let cardHover    = tick
    static let border       = rule
    static let divider      = ruleSoft

    static let textPrimary   = ink
    static let textSecondary = ink2
    static let textTertiary  = ink3

    static let radius: CGFloat = 4

    /// 面板固定尺寸：所有页面共用同一高度，切换页面时菜单栏窗口不需要改变大小
    static let panelWidth: CGFloat = 380
    static let panelHeight: CGFloat = 600

    // MARK: - 动态色工具

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

// MARK: - 字体

enum DSFont {
    /// 等宽微标签：8–9pt，拉开字距
    static func label(_ size: CGFloat = 8.5, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// 正文 / 标签
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    /// 数值：表格数字，刷新时不跳宽
    static func figure(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
}

// MARK: - 安全下标

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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

// MARK: - 线

/// 横向发丝线，贯穿整个面板
struct Hairline: View {
    var color: Color = DS.rule
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

/// 纵向发丝线，用于分栏
struct VRule: View {
    var color: Color = DS.ruleSoft
    var body: some View {
        Rectangle().fill(color).frame(width: 1)
    }
}

struct DSDivider: View {
    var body: some View { Hairline(color: DS.ruleSoft) }
}

// MARK: - 标签

/// 区块头：中文名 + 右侧等宽元信息
struct SectionHead: View {
    let title: String
    var meta: String?
    var accessory: AnyView?

    init(_ title: String, meta: String? = nil) {
        self.title = title
        self.meta = meta
        self.accessory = nil
    }

    init<T: View>(_ title: String, meta: String? = nil, @ViewBuilder accessory: () -> T) {
        self.title = title
        self.meta = meta
        self.accessory = AnyView(accessory())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(DSFont.text(10.5, weight: .semibold))
                .foregroundStyle(DS.ink)
                .tracking(0.4)

            Spacer(minLength: 6)

            if let accessory {
                accessory
            } else if let meta {
                Text(meta)
                    .font(DSFont.label(8.5))
                    .tracking(0.9)
                    .foregroundStyle(DS.ink3)
            }
        }
    }
}

/// 等宽微标签（大写、拉开字距）
struct MonoTag: View {
    let text: String
    var color: Color = DS.ink3
    var size: CGFloat = 8.5

    var body: some View {
        Text(text)
            .font(DSFont.label(size))
            .tracking(1.0)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

struct DSSectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DSFont.text(10.5, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(DS.ink)
    }
}

// MARK: - 状态标记（取代胶囊）

/// 扁平状态标记：一个方点 + 等宽文字 + 细线描边，无胶囊填充
struct DSPill: View {
    let text: String
    var color: Color = DS.ink3
    var icon: String?
    var showsDot: Bool = true
    var size: CGFloat = 8.5

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
            } else if showsDot {
                Rectangle()
                    .fill(color)
                    .frame(width: 4, height: 4)
            }
            Text(text)
                .font(DSFont.label(size))
                .tracking(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.vertical, 1)
    }
}

// MARK: - 按钮

/// 主操作：墨色实底，方角，无投影
struct DSPrimaryButtonStyle: ButtonStyle {
    var color: Color = DS.ink
    var expands: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.text(10.5, weight: .medium))
            .foregroundStyle(DS.ground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: expands ? .infinity : nil)
            .background(
                Rectangle().fill(color.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 次操作：发丝线描边，透明底
struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.text(10.5, weight: .medium))
            .foregroundStyle(DS.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Rectangle().fill(configuration.isPressed ? DS.tick : Color.clear)
            )
            .overlay(
                Rectangle().strokeBorder(DS.rule, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 文字操作：无框，按下变灰
struct DSGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.text(10.5, weight: .medium))
            .foregroundStyle(configuration.isPressed ? DS.ink3 : DS.ink2)
    }
}

/// 刻度式分段选择：选中项由信号色下划线标记，不用胶囊底
struct DSSegmentedScale: View {
    let options: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, label in
                let selected = index == selectedIndex

                Button {
                    onSelect(index)
                } label: {
                    VStack(spacing: 5) {
                        Text(label)
                            .font(DSFont.text(9.5, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? DS.ink : DS.ink3)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(selected ? DS.signal : Color.clear)
                            .frame(height: 1.5)
                    }
                    .padding(.top, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .top) { Hairline(color: DS.ruleSoft) }
    }
}

// MARK: - 图标操作

/// 扁平图标操作：默认墨灰，悬停变墨并出现 1px 信号色刻度
struct DSIconButton: View {
    let systemName: String
    var help: String = ""
    var tint: Color = DS.ink3
    var hoverTint: Color = DS.ink
    var hoverFill: Color = .clear
    var size: CGFloat = 24
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.48, weight: .medium))
                    .foregroundStyle(hovering ? hoverTint : tint)
                    .frame(width: size, height: size * 0.72)

                Rectangle()
                    .fill(hovering ? DS.signal : Color.clear)
                    .frame(width: size * 0.62, height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - 品牌标记

/// 字标：1px 线框 + 等宽字母，取代渐变方块
struct DSLogo: View {
    var size: CGFloat = 28
    var label: String = "DS"

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(DS.ink.opacity(0.55), lineWidth: 1)
            Text(label)
                .font(DSFont.label(size * 0.34, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(DS.ink)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 区块容器

/// 台账区块：只留顶部一条发丝线，无填充、无圆角、无阴影
struct DSCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Hairline(color: DS.ruleSoft)
            }
    }
}

extension View {
    func dsCard(padding: CGFloat = 14, radius: CGFloat = DS.radius) -> some View {
        modifier(DSCardModifier(padding: padding, radius: radius))
    }
}

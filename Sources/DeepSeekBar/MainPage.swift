import SwiftUI
import AppKit

/// 主面板 · 一块连续的仪表面板。
/// 读法自上而下：余额（主角）→ 四个总量刻度 → 30 天消费刻度 → 模型构成 → 操作。
struct MainPage: View {
    @EnvironmentObject var state: AppState
    var onOpenSettings: () -> Void
    var onOpenRecharge: () -> Void
    var onOpenAPIKeys: () -> Void

    @State private var hoveredDay: Date?

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()

            balanceBlock

            usageSection

            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.ground)
        .animation(.easeOut(duration: 0.24), value: state.status)
        .animation(.easeOut(duration: 0.26), value: state.officialState)
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 8) {
            Text("DEEPSEEK BAR")
                .font(DSFont.label(8, weight: .bold))
                .tracking(1.9)
                .foregroundStyle(DS.ink2)

            Rectangle()
                .fill(DS.rule)
                .frame(width: 14, height: 1)

            Text("余额与用量")
                .font(DSFont.text(9, weight: .medium))
                .foregroundStyle(DS.ink3)
                .tracking(0.6)

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Rectangle()
                    .fill(heroStatus.tint)
                    .frame(width: 4, height: 4)

                Text(heroStatus.text)
                    .font(DSFont.label(8.5))
                    .tracking(0.8)
                    .foregroundStyle(heroStatus.tint)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
    }

    private var heroStatus: (text: String, tint: Color) {
        switch state.status {
        case .ok:            return ("OK", DS.ok)
        case .loading:       return ("SYNC", DS.ink3)
        case .notConfigured:
            return (state.balanceSource == .webAccount ? "NO LOGIN" : "NO KEY", DS.ink3)
        case .failed:        return ("ERROR", DS.err)
        case .insufficient:  return ("EMPTY", DS.warn)
        }
    }

    // MARK: - 余额（主角）

    @ViewBuilder
    private var balanceBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("账户余额")
                    .font(DSFont.text(10, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(DS.ink3)
                Spacer()
                MonoTag(text: currencyCode, color: DS.ink3)
            }

            if case .ok(let info) = state.status {
                balanceFigure(info)
            } else {
                placeholderFigure
            }

            balanceFootnotes
                .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    private var currencyCode: String {
        if case .ok(let info) = state.status { return info.currency.uppercased() }
        return "CNY"
    }

    private func balanceFigure(_ info: BalanceInfo) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(currencySymbol(info.currency))
                .font(DSFont.figure(21, weight: .medium))
                .foregroundStyle(DS.ink2)
                .padding(.trailing, 2)

            Text(String(format: "%.2f", info.totalBalance))
                .font(DSFont.figure(46, weight: .semibold))
                .tracking(-1.6)
                .foregroundStyle(DS.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.top, 4)
    }

    private var placeholderFigure: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("¥")
                .font(DSFont.figure(21, weight: .medium))
                .foregroundStyle(DS.ink3)
                .padding(.trailing, 2)
            Text("——")
                .font(DSFont.figure(46, weight: .semibold))
                .tracking(-1.6)
                .foregroundStyle(DS.ink3.opacity(0.5))
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var balanceFootnotes: some View {
        switch state.status {
        case .ok(let info):
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .center, spacing: 14) {
                    if info.toppedUpBalance > 0 || info.grantedBalance > 0 {
                        wallet("充值", info.toppedUpBalance, symbol: currencySymbol(info.currency))
                        wallet("赠送", info.grantedBalance, symbol: currencySymbol(info.currency))
                    } else {
                        Text("无钱包明细")
                            .font(DSFont.text(9))
                            .foregroundStyle(DS.ink3)
                    }

                    Spacer(minLength: 6)

                    Button(action: onOpenRecharge) {
                        HStack(spacing: 3) {
                            Text("充值")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 7.5, weight: .bold))
                        }
                    }
                    .buttonStyle(DSSecondaryButtonStyle())
                    .help("进入充值页")
                }

                if let runway = runwayText(info) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(DS.signal)
                            .frame(width: 10, height: 1)
                        Text(runway)
                            .font(DSFont.text(9))
                            .foregroundStyle(DS.ink3)
                            .lineLimit(1)
                    }
                }
            }

        case .notConfigured:
            HStack(spacing: 10) {
                Text(notConfiguredHint)
                    .font(DSFont.text(9.5))
                    .foregroundStyle(DS.ink3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                if state.balanceSource == .webAccount {
                    Button("网页登录") { state.openOfficialLogin() }
                        .buttonStyle(DSPrimaryButtonStyle())
                } else {
                    Button("连接账户", action: onOpenSettings)
                        .buttonStyle(DSPrimaryButtonStyle())
                }
            }

        case .loading:
            Text("正在获取余额…")
                .font(DSFont.label(9))
                .foregroundStyle(DS.ink3)

        case .failed(let msg), .insufficient(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Text(msg)
                    .font(DSFont.text(9.5))
                    .foregroundStyle(DS.ink2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("重新获取") {
                        Task { await state.refreshBalance() }
                    }
                    .buttonStyle(DSSecondaryButtonStyle())

                    if case .insufficient = state.status {
                        Button("去充值", action: onOpenRecharge)
                            .buttonStyle(DSPrimaryButtonStyle())
                    }
                    Spacer()
                }
            }
        }
    }

    private var notConfiguredHint: String {
        switch state.balanceSource {
        case .webAccount: return "网页账号还没登录，登录后即显示余额"
        case .apiKey:     return "填入 API Key 后显示余额"
        case .auto:       return "填 API Key，或网页登录，两者取其一"
        }
    }

    private func wallet(_ title: String, _ value: Double, symbol: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink3)
            Text(symbol + String(format: "%.2f", value))
                .font(DSFont.label(9.5, weight: .medium))
                .foregroundStyle(DS.ink2)
                .lineLimit(1)
        }
    }

    /// 把余额换算成「还能撑多久」，让数字变成判断。
    private func runwayText(_ info: BalanceInfo) -> String? {
        guard state.officialData.fetchedAt != nil else { return nil }
        let daily = state.officialData.summary.monthlyUsage / 30
        guard daily > 0.005, info.totalBalance > 0 else { return nil }

        let days = info.totalBalance / daily
        let span: String
        if days >= 365 {
            span = "一年以上"
        } else if days >= 60 {
            span = String(format: "%.1f 个月", days / 30)
        } else {
            span = "\(Int(days.rounded())) 天"
        }
        return "按日均 ¥\(String(format: "%.2f", daily)) 计，余额约可用 \(span)"
    }

    private func currencySymbol(_ code: String) -> String {
        switch code.uppercased() {
        case "CNY", "RMB": return "¥"
        case "USD":        return "$"
        default:           return code
        }
    }

    // MARK: - 用量

    @ViewBuilder
    private var usageSection: some View {
        switch state.officialState {
        case .ok:
            statsBlock
            trendBlock
            if !modelSlices.isEmpty { modelsBlock }
        case .loading:
            if state.officialData.fetchedAt != nil {
                statsBlock
                trendBlock
                if !modelSlices.isEmpty { modelsBlock }
            } else {
                syncingBlock
            }
        case .failed(let msg):
            officialErrorBlock(msg)
        case .notAuthorized:
            officialConnectBlock
        }
    }

    // MARK: 四个总量刻度

    private var statsBlock: some View {
        let summary = state.officialData.summary
        return VStack(spacing: 0) {
            Hairline(color: DS.ruleSoft)

            HStack(spacing: 0) {
                statCell("累计消费", value: String(format: "%.2f", summary.totalUsage), unit: "¥")
                VRule().padding(.vertical, 3)
                statCell("近 30 天", value: String(format: "%.2f", summary.monthlyUsage), unit: "¥")
                VRule().padding(.vertical, 3)
                statCell("请求", value: summary.totalRequestCount.formatted(), unit: nil)
                VRule().padding(.vertical, 3)
                statCell("TOKENS", value: Self.compactTokens(summary.totalTokens), unit: nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if case .loading = state.officialState {
                HStack(spacing: 5) {
                    Rectangle().fill(DS.warn).frame(width: 4, height: 4)
                    Text("SYNCING")
                        .font(DSFont.label(7.5))
                        .tracking(1.4)
                        .foregroundStyle(DS.ink3)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func statCell(_ label: String, value: String, unit: String?) -> some View {
        let isLatin = label.allSatisfy { $0.isASCII }
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(isLatin ? DSFont.label(8, weight: .medium) : DSFont.text(9, weight: .medium))
                .tracking(isLatin ? 1.3 : 0.1)
                .foregroundStyle(DS.ink3)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if let unit {
                    Text(unit)
                        .font(DSFont.figure(10, weight: .medium))
                        .foregroundStyle(DS.ink3)
                }
                Text(value)
                    .font(DSFont.figure(14, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    // MARK: 30 天刻度条

    private var trendBlock: some View {
        let days = chartDays
        let peak = max(days.map(\.amount).max() ?? 0, 0.01)
        let total = days.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 0) {
            Hairline(color: DS.ruleSoft)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("消费趋势")
                    .font(DSFont.text(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(DS.ink)

                Spacer(minLength: 4)

                if let hovered = hoveredDay, let day = days.first(where: { $0.date == hovered }) {
                    Text(day.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                        .font(DSFont.label(8.5))
                        .foregroundStyle(DS.ink3)
                    Text("¥" + String(format: "%.2f", day.amount))
                        .font(DSFont.figure(10, weight: .semibold))
                        .foregroundStyle(DS.signal)
                } else {
                    Text("30D")
                        .font(DSFont.label(8.5))
                        .tracking(1.0)
                        .foregroundStyle(DS.ink3)
                    Text("¥" + String(format: "%.2f", total))
                        .font(DSFont.figure(10, weight: .semibold))
                        .foregroundStyle(DS.ink2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            SpendStrip(days: days, peak: peak, hovered: $hoveredDay)
                .frame(height: 118)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Hairline(color: DS.rule)

            HStack(spacing: 6) {
                Text(axisLabel(days.first?.date))
                Spacer()
                if let peakDay = days.max(by: { $0.amount < $1.amount }), peakDay.amount > 0 {
                    Text("峰值 ¥" + String(format: "%.2f", peakDay.amount) + " · " + axisLabel(peakDay.date))
                }
                Spacer()
                Text(axisLabel(days.last?.date))
            }
            .font(DSFont.label(7.5, weight: .regular))
            .tracking(0.6)
            .foregroundStyle(DS.ink3)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
    }

    private func axisLabel(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    // MARK: 模型构成

    private var modelsBlock: some View {
        let models = modelSlices
        let total = models.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 0) {
            Hairline(color: DS.ruleSoft)

            HStack(alignment: .firstTextBaseline) {
                Text("模型构成")
                    .font(DSFont.text(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(DS.ink)
                Spacer()
                MonoTag(text: "TOP \(models.count)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // 36 格刻度尺：一格约 2.8%，比一条色带更像仪表；单一模型时不画，避免空刻度
            if models.count > 1 {
                ShareScale(models: models, total: total, color: segmentColor)
                    .frame(height: 8)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 0) {
                ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                    HStack(spacing: 7) {
                        Rectangle()
                            .fill(segmentColor(index))
                            .frame(width: 5, height: 5)
                        Text(model.name)
                            .font(DSFont.text(10))
                            .foregroundStyle(DS.ink2)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(model.share.formatted(.percent.precision(.fractionLength(0))))
                            .font(DSFont.label(8.5, weight: .regular))
                            .foregroundStyle(DS.ink3)
                            .frame(width: 34, alignment: .trailing)
                        Text("¥" + String(format: "%.2f", model.amount))
                            .font(DSFont.figure(9.5, weight: .medium))
                            .foregroundStyle(DS.ink)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
    }

    /// 构成色阶：三档墨色，把唯一的信号色留给「当前」状态
    private func segmentColor(_ index: Int) -> Color {
        switch index {
        case 0:  return DS.ink.opacity(0.78)
        case 1:  return DS.ink.opacity(0.48)
        default: return DS.ink.opacity(0.28)
        }
    }

    // MARK: - 官方用量状态

    private var officialConnectBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline(color: DS.ruleSoft)

            HStack(alignment: .firstTextBaseline) {
                Text("官方用量")
                    .font(DSFont.text(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(DS.ink)
                Spacer()
                MonoTag(text: "NOT LINKED")
            }

            Text("登录一次 platform.deepseek.com，即可拉取与网页版一致的消费趋势、请求次数与模型构成。")
                .font(DSFont.text(9.5))
                .foregroundStyle(DS.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("网页登录授权") { state.openOfficialLogin() }
                    .buttonStyle(DSPrimaryButtonStyle())
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var syncingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline(color: DS.ruleSoft)

            HStack(alignment: .firstTextBaseline) {
                Text("官方用量")
                    .font(DSFont.text(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(DS.ink)
                Spacer()
                MonoTag(text: "SYNCING", color: DS.warn)
            }

            ZStack(alignment: .leading) {
                Rectangle().fill(DS.tick).frame(height: 1)
                Rectangle()
                    .fill(DS.signal)
                    .frame(width: 64, height: 1)
                    .offset(x: 0)
                    .modifier(PulseOffset())
            }

            Text("正在同步官方消费数据…")
                .font(DSFont.text(9.5))
                .foregroundStyle(DS.ink3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func officialErrorBlock(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline(color: DS.ruleSoft)

            HStack(alignment: .firstTextBaseline) {
                Text("官方用量")
                    .font(DSFont.text(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(DS.ink)
                Spacer()
                MonoTag(text: "FAILED", color: DS.err)
            }

            Text(message)
                .font(DSFont.text(9.5))
                .foregroundStyle(DS.ink2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("重新授权") { state.openOfficialLogin() }
                    .buttonStyle(DSSecondaryButtonStyle())
                Button("重试") {
                    Task { await state.refreshOfficial() }
                }
                .buttonStyle(DSPrimaryButtonStyle())
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - 底栏

    private var footer: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("余额")
                        .font(DSFont.text(8.5))
                        .foregroundStyle(DS.ink3)
                    Text(state.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "—")
                        .font(DSFont.label(8.5, weight: .medium))
                        .foregroundStyle(DS.ink2)

                    Text("用量")
                        .font(DSFont.text(8.5))
                        .foregroundStyle(DS.ink3)
                        .padding(.leading, 2)
                    Text(state.officialData.fetchedAt?.formatted(date: .omitted, time: .shortened) ?? "—")
                        .font(DSFont.label(8.5, weight: .medium))
                        .foregroundStyle(DS.ink2)
                }

                Spacer(minLength: 4)

                if state.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                        .frame(width: 24, height: 24)
                } else {
                    DSIconButton(systemName: "arrow.clockwise", help: "刷新全部数据", size: 24) {
                        Task { await state.refreshAll() }
                    }
                }

                DSIconButton(systemName: "key", help: "API 管理", size: 24, action: onOpenAPIKeys)
                DSIconButton(systemName: "gearshape", help: "设置", size: 24, action: onOpenSettings)
                DSIconButton(systemName: "power", help: "退出 DeepSeekBar", size: 24) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
        }
    }

    // MARK: - 数据整理

    private var chartDays: [ChartDay] {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        let today = utc.startOfDay(for: Date())
        var byDay: [Date: Double] = [:]
        for i in 0..<30 {
            byDay[today.addingTimeInterval(-Double(i) * 86400)] = 0
        }
        for point in state.officialData.dailyCost {
            byDay[utc.startOfDay(for: point.date), default: 0] += point.amount
        }
        return byDay
            .sorted { $0.key < $1.key }
            .map { ChartDay(date: $0.key, amount: $0.value) }
    }

    private var modelSlices: [ModelSlice] {
        let positive = state.officialData.models.filter { $0.value > 0.0001 }
        guard !positive.isEmpty else { return [] }

        let total = positive.values.reduce(0, +)

        return positive
            .sorted { $0.value > $1.value }
            .prefix(3)
            .enumerated()
            .map { index, entry in
                ModelSlice(
                    id: entry.key,
                    name: friendlyModelName(entry.key),
                    amount: entry.value,
                    share: total > 0 ? entry.value / total : 0,
                    order: index
                )
            }
    }

    private func friendlyModelName(_ raw: String) -> String {
        let known: [String: String] = [
            "deepseek-chat": "DeepSeek Chat",
            "deepseek-reasoner": "DeepSeek Reasoner",
            "deepseek-flash": "DeepSeek Flash",
            "deepseek-v4-flash": "DeepSeek V4 Flash",
            "deepseek-v4-pro": "DeepSeek V4 Pro",
            "deepseek-v4-flash-vision-exp": "DeepSeek V4 Flash Vision（实验）",
            "deepseek-v4.1-flash-expires-on-0910": "DeepSeek V4.1 Flash"
        ]
        if let name = known[raw.lowercased()] { return name }

        return raw
            .replacingOccurrences(of: "deepseek-", with: "DeepSeek ")
            .replacingOccurrences(of: "DeepSeek-", with: "DeepSeek ")
    }

    static func compactTokens(_ value: Double) -> String {
        if value >= 100_000_000 { return String(format: "%.1f亿", value / 100_000_000) }
        if value >= 10_000 { return String(format: "%.1f万", value / 10_000) }
        return value.formatted(.number.grouping(.automatic))
    }
}

// MARK: - 模型占比刻度尺

/// 36 格等距刻度：填充格代表占比，空格只留基线短刻度。
private struct ShareScale: View {
    let models: [ModelSlice]
    let total: Double
    let color: (Int) -> Color

    private let ticks = 36

    var body: some View {
        GeometryReader { geo in
            let pitch = geo.size.width / CGFloat(ticks)
            let tickWidth = max(1.5, pitch - 4.4)

            HStack(alignment: .center, spacing: pitch - tickWidth) {
                ForEach(0..<ticks, id: \.self) { tick in
                    let index = modelIndex(for: tick)
                    Rectangle()
                        .fill(index.map { color($0) } ?? DS.rule)
                        .frame(width: tickWidth, height: index == nil ? 2 : 8)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
    }

    private func modelIndex(for tick: Int) -> Int? {
        guard total > 0 else { return nil }
        var accumulated = 0.0
        for (index, model) in models.enumerated() {
            accumulated += model.amount / total
            if Double(tick) + 0.5 < accumulated * Double(ticks) { return index }
        }
        return nil
    }
}

// MARK: - 30 天消费刻度条

/// 30 根 1px 级细柱立在一条基线上；今天在末端，悬停出光标与读数。
private struct SpendStrip: View {
    let days: [ChartDay]
    let peak: Double
    @Binding var hovered: Date?

    var body: some View {
        GeometryReader { geo in
            let count = max(days.count, 1)
            let pitch = geo.size.width / CGFloat(count)
            let barWidth = max(1.5, pitch - 3.2)
            let today = days.last?.date

            ZStack(alignment: .bottomLeading) {
                // 三层水平刻度线，像坐标纸一样托住柱体
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle().fill(DS.ruleSoft.opacity(0.7)).frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle().fill(DS.ruleSoft.opacity(0.7)).frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle().fill(DS.ruleSoft.opacity(0.7)).frame(height: 1)
                    Spacer(minLength: 0)
                }

                // 基线
                Rectangle()
                    .fill(DS.rule)
                    .frame(height: 1)

                HStack(alignment: .bottom, spacing: pitch - barWidth) {
                    ForEach(days) { day in
                        let ratio = min(1, day.amount / peak)
                        let isHovered = hovered == day.date
                        let isToday = day.date == today

                        Rectangle()
                            .fill(barColor(isHovered: isHovered, isToday: isToday, value: day.amount))
                            .frame(
                                width: day.amount <= 0.0001 && !isHovered ? min(3, barWidth) : barWidth,
                                height: heightFor(ratio, isToday: isToday, maxHeight: geo.size.height - 1)
                            )
                    }
                }

                // 悬停光标
                if let hovered, let index = days.firstIndex(where: { $0.date == hovered }) {
                    Rectangle()
                        .fill(DS.signal.opacity(0.55))
                        .frame(width: 1)
                        .offset(x: CGFloat(index) * pitch + barWidth / 2)
                }
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: geo.size.height)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let index = Int(location.x / pitch)
                            guard index >= 0, index < days.count else {
                                hovered = nil
                                return
                            }
                            hovered = days[index].date
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
    }

    private func heightFor(_ ratio: Double, isToday: Bool, maxHeight: CGFloat) -> CGFloat {
        if ratio <= 0.0001 { return isToday ? 3 : 1 }
        return max(2, CGFloat(ratio) * maxHeight)
    }

    private func barColor(isHovered: Bool, isToday: Bool, value: Double) -> Color {
        if isHovered { return DS.signal }
        if value <= 0.0001 { return isToday ? DS.ink3 : DS.rule.opacity(0.9) }
        return isToday ? DS.ink : DS.ink.opacity(0.46)
    }
}

// MARK: - 加载脉冲

private struct PulseOffset: ViewModifier {
    @State private var offset: CGFloat = -64
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(visible ? 1 : 0)
            .onAppear {
                visible = true
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    offset = 240
                }
            }
    }
}

// MARK: - 辅助类型

private struct ChartDay: Identifiable {
    let date: Date
    let amount: Double
    var id: Date { date }
}

private struct ModelSlice: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let share: Double
    let order: Int

    func sharedRatio(_ total: Double) -> Double {
        total > 0 ? amount / total : 0
    }
}

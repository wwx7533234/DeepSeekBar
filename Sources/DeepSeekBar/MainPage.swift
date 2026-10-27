import SwiftUI
import Charts
import AppKit

struct MainPage: View {
    @EnvironmentObject var state: AppState
    var onOpenSettings: () -> Void
    var onOpenRecharge: () -> Void
    var onOpenAPIKeys: () -> Void

    @State private var hoveredDay: Date?

    var body: some View {
        VStack(spacing: 12) {
            header
            balanceHero
            usageSection
            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .animation(.snappy(duration: 0.28), value: state.status)
        .animation(.snappy(duration: 0.30), value: state.officialState)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            DSLogo(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("DeepSeek")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(DS.textPrimary)
                Text("余额与用量")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(DS.textTertiary)
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - 余额 Hero 卡

    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("账户余额")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                heroStatusPill
            }
            .padding(.bottom, 9)

            heroBody
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                DS.heroGradient
                Circle()
                    .fill(.white.opacity(0.09))
                    .frame(width: 170, height: 170)
                    .blur(radius: 2)
                    .offset(x: 150, y: -88)
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 120, height: 120)
                    .offset(x: 160, y: 66)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
        )
        .shadow(color: DS.brand.opacity(0.30), radius: 18, x: 0, y: 8)
    }

    private var heroStatus: (text: String, icon: String, tint: Color) {
        switch state.status {
        case .ok:
            return ("可用", "checkmark.circle.fill", Color(hex: 0xB9F5CE))
        case .loading:
            return ("同步中", "arrow.triangle.2.circlepath", .white.opacity(0.88))
        case .notConfigured:
            return ("未连接", "link", .white.opacity(0.72))
        case .failed:
            return ("异常", "exclamationmark.triangle.fill", Color(hex: 0xFFD8A8))
        case .insufficient:
            return ("不可用", "xmark.circle.fill", Color(hex: 0xFFC9C9))
        }
    }

    private var heroStatusPill: some View {
        let s = heroStatus
        return HStack(spacing: 4) {
            Image(systemName: s.icon)
                .font(.system(size: 8.5, weight: .bold))
            Text(s.text)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(s.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.16)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }

    @ViewBuilder
    private var heroBody: some View {
        switch state.status {
        case .notConfigured:
            VStack(alignment: .leading, spacing: 9) {
                Text("连接你的 DeepSeek 账户")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                Text("填入 API Key 后，菜单栏会实时显示账户余额。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.70))
                Button("去配置") { onOpenSettings() }
                    .buttonStyle(HeroButtonStyle())
                    .padding(.top, 1)
            }

        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("正在获取余额…")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(height: 48, alignment: .leading)

        case .ok(let info):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currencySymbol(info.currency) + String(format: "%.2f", info.totalBalance))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(info.currency)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(spacing: 7) {
                    if info.toppedUpBalance > 0 {
                        walletChip("充值", info.toppedUpBalance, symbol: currencySymbol(info.currency))
                    }
                    if info.grantedBalance > 0 {
                        walletChip("赠送", info.grantedBalance, symbol: currencySymbol(info.currency))
                    }
                    if info.toppedUpBalance <= 0 && info.grantedBalance <= 0 {
                        Text("暂无钱包明细")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 4)
                    topUpButton
                }
            }

        case .failed(let msg):
            heroError(msg, showTopUp: false)

        case .insufficient(let msg):
            heroError(msg, showTopUp: true)
        }
    }

    private var topUpButton: some View {
        Button {
            onOpenRecharge()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                Text("充值")
            }
        }
        .buttonStyle(HeroButtonStyle())
        .layoutPriority(1)
        .help("进入充值页")
        .accessibilityLabel("充值")
    }

    private func heroError(_ message: String, showTopUp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0xFFD8A8))
                    .padding(.top, 1)
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 9) {
                if showTopUp {
                    topUpButton

                    Button("重新获取") {
                        Task { await state.refreshBalance() }
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .buttonStyle(.plain)
                } else {
                    Button("重新获取") {
                        Task { await state.refreshBalance() }
                    }
                    .buttonStyle(HeroButtonStyle())
                }
            }
        }
    }

    private func walletChip(_ title: String, _ value: Double, symbol: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.60))
            Text(symbol + String(format: "%.2f", value))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.13)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
    }

    private func currencySymbol(_ code: String) -> String {
        switch code.uppercased() {
        case "CNY", "RMB": return "¥"
        case "USD":        return "$"
        default:           return code
        }
    }

    // MARK: - 用量区域

    @ViewBuilder
    private var usageSection: some View {
        switch state.officialState {
        case .ok:
            usageCard
        case .loading:
            // 已有数据时原地展示，右上角切「同步中」，避免手动刷新时面板高度跳动。
            if state.officialData.fetchedAt != nil {
                usageCard
            } else {
                officialLoadingCard
            }
        case .failed(let msg):
            officialErrorCard(msg)
        case .notAuthorized:
            officialConnectCard
        }
    }

    private var usageCard: some View {
        let summary = state.officialData.summary
        let dailyAverage = summary.monthlyUsage / 30
        let days = chartDays
        let models = modelSlices

        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Text("用量概览")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Spacer()
                if case .loading = state.officialState {
                    DSPill(text: "同步中", color: DS.amber, icon: "arrow.triangle.2.circlepath")
                } else {
                    DSPill(text: "官方数据", color: DS.brand, icon: "checkmark.seal.fill")
                }
            }

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("累计消费")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DS.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("¥")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.textSecondary)
                        Text(String(format: "%.2f", summary.totalUsage))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DS.textPrimary)
                            .contentTransition(.numericText())
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("日均")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                    Text("¥" + String(format: "%.2f", dailyAverage))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.textSecondary)
                }
                .padding(.top, 2)
            }

            HStack(spacing: 7) {
                miniStat("近 30 天", "¥" + String(format: "%.2f", summary.monthlyUsage))
                miniStat("请求次数", summary.totalRequestCount.formatted())
                miniStat("Tokens", Self.compactTokens(summary.totalTokens))
            }

            DSDivider()

            chartBlock(days)

            if !models.isEmpty {
                DSDivider()
                modelBlock(models)
            }
        }
        .dsCard(padding: 14)
    }

    private func miniStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(DS.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DS.cardSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DS.border.opacity(0.75), lineWidth: 0.6)
        )
    }

    // MARK: - 图表

    private func chartBlock(_ days: [ChartDay]) -> some View {
        let peak = days.map(\.amount).max() ?? 0
        let upperBound = max(peak * 1.22, 0.01)
        let first = days.first?.date ?? Date()
        let last = days.last?.date ?? Date()
        let domainStart = first.addingTimeInterval(-2 * 86400)
        let domainEnd = last.addingTimeInterval(2 * 86400)
        let chartWidth = CGFloat(max(days.count + 4, 8)) * 28
        let total = days.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("近 30 天消费趋势")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)

                Spacer(minLength: 6)

                if let hovered = hoveredDay,
                   let day = days.first(where: { $0.date == hovered }) {
                    Text("\(day.date.formatted(.dateTime.month().day())) · ¥\(String(format: "%.2f", day.amount))")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.textPrimary)
                } else {
                    Text("合计 ¥" + String(format: "%.2f", total))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.textTertiary)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    Chart(days) { day in
                        BarMark(
                            x: .value("日期", day.date, unit: .day),
                            y: .value("消费", day.amount),
                            width: .ratio(0.56)
                        )
                        .foregroundStyle(
                            hoveredDay == day.date
                                ? AnyShapeStyle(DS.brand)
                                : AnyShapeStyle(DS.barGradient)
                        )
                        .opacity(hoveredDay == nil || hoveredDay == day.date ? 1 : 0.42)
                        .cornerRadius(3)
                    }
                    .chartXScale(domain: domainStart...domainEnd)
                    .chartYScale(domain: 0...upperBound)
                    .chartXAxis {
                        AxisMarks(preset: .aligned, values: .stride(by: .day, count: 2)) { _ in
                            AxisGridLine().foregroundStyle(Color.clear)
                            AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(DS.textTertiary)
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartPlotStyle { plotArea in
                        plotArea.background(alignment: .bottom) {
                            Rectangle()
                                .fill(DS.divider)
                                .frame(height: 0.7)
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let frame = geo[plotFrame]
                                        let x = location.x - frame.origin.x
                                        guard x >= 0, x <= frame.width else {
                                            hoveredDay = nil
                                            return
                                        }
                                        if let date: Date = proxy.value(atX: x) {
                                            hoveredDay = days.min {
                                                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                            }?.date
                                        }
                                    case .ended:
                                        hoveredDay = nil
                                    }
                                }
                        }
                    }
                    .frame(width: chartWidth, height: 82)
                    .id("usage-chart")
                }
                .defaultScrollAnchor(.trailing)
                .onAppear { scrollToLatest(proxy) }
                .onChange(of: days.count) { _, _ in scrollToLatest(proxy) }
            }
            .frame(height: 98)
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("usage-chart", anchor: .trailing)
            }
        }
    }

    // MARK: - 模型分布

    private func modelBlock(_ models: [ModelSlice]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("模型分布")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
                Spacer()
                Text("近 30 天")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textTertiary)
            }

            ForEach(models) { model in
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.color)
                            .frame(width: 5, height: 5)
                        Text(model.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(model.share.formatted(.percent.precision(.fractionLength(0))))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(DS.textTertiary)
                        Text("¥" + String(format: "%.2f", model.amount))
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.cardSoft)
                            Capsule()
                                .fill(model.color.opacity(0.88))
                                .frame(width: max(4, geo.size.width * model.share))
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
    }

    // MARK: - 官方授权 / 加载 / 错误

    private var officialConnectCard: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.brand.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 13.5))
                    .foregroundStyle(DS.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("解锁官方用量")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Text("登录一次，查看与网页版一致的消费趋势")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button("授权") { state.openOfficialLogin() }
                .buttonStyle(DSPrimaryButtonStyle())
        }
        .dsCard(padding: 13)
    }

    private var officialLoadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("正在同步官方用量")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Text("余额已更新，官方的消费数据稍等片刻…")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DS.textSecondary)
            }
            Spacer()
        }
        .dsCard(padding: 14)
    }

    private func officialErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.amber)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("官方用量同步失败")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(message)
                        .font(.system(size: 9.5))
                        .foregroundStyle(DS.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
            }

            HStack(spacing: 7) {
                Button("重新授权") { state.openOfficialLogin() }
                    .buttonStyle(DSPrimaryButtonStyle())
                Button("重试") {
                    Task { await state.refreshOfficial() }
                }
                .buttonStyle(DSSecondaryButtonStyle())
                Spacer()
            }
        }
        .dsCard(padding: 13)
    }

    // MARK: - 底部

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 8, weight: .medium))

            if let at = state.lastUpdated {
                Text("余额 \(at.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("等待首次同步")
            }

            if let officialAt = state.officialData.fetchedAt {
                Text("·").opacity(0.5)
                Text("用量 \(officialAt.formatted(date: .omitted, time: .shortened))")
            }

            Spacer()

            if state.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.65)
                    .frame(width: 22, height: 22)
            } else {
                DSIconButton(systemName: "arrow.clockwise", help: "刷新全部数据", size: 22) {
                    Task { await state.refreshAll() }
                }
            }

            DSIconButton(systemName: "key.fill", help: "API 管理", size: 22, action: onOpenAPIKeys)
            DSIconButton(systemName: "gearshape", help: "设置", size: 22, action: onOpenSettings)
            DSIconButton(systemName: "power", help: "退出 DeepSeekBar", size: 22) {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(DS.textTertiary)
        .padding(.horizontal, 2)
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
        let palette = [DS.brand, DS.violet, DS.teal, DS.amber]

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
                    color: palette[index % palette.count]
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
    let color: Color
}

private struct HeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(DS.brandDeep)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

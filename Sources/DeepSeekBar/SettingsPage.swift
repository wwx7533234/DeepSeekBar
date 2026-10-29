import SwiftUI
import AppKit

/// 设置 · 与主面板同一套台账语言：区块头 + 发丝线 + 方角控件。
struct SettingsPage: View {
    @EnvironmentObject var state: AppState
    var onBack: () -> Void

    @State private var keyInput = ""
    @State private var justSaved = false
    @State private var isTesting = false
    @State private var testResult: String?
    @FocusState private var keyFocused: Bool

    private let refreshOptions: [(label: String, value: TimeInterval)] = [
        ("30 秒", 30),
        ("1 分钟", 60),
        ("5 分钟", 300),
        ("15 分钟", 900),
        ("30 分钟", 1800)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    sourceSection
                    menuBarSection
                    accountSection
                    officialSection
                    refreshSection
                    aboutSection
                    Spacer(minLength: 0)
                }
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.ground)
        .onAppear {
            keyInput = state.settings.apiKey ?? ""
        }
        .onChange(of: state.apiKeyConfigured) { _, configured in
            if !configured { keyInput = "" }
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("设置")
                    .font(DSFont.text(13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(DS.ink)

                Rectangle()
                    .fill(DS.rule)
                    .frame(width: 14, height: 1)

                Text("SETTINGS")
                    .font(DSFont.label(8, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(DS.ink3)

                Spacer()

                MonoTag(text: "LOCAL ONLY", color: DS.ink3)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            Hairline()
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 8) {
                DSIconButton(systemName: "chevron.left", help: "返回", size: 24, action: onBack)
                Text("返回")
                    .font(DSFont.text(10, weight: .medium))
                    .foregroundStyle(DS.ink2)
                    .onTapGesture { onBack() }

                Spacer()

                DSIconButton(systemName: "power", help: "退出 DeepSeekBar", size: 24) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
        }
    }

    // MARK: - 余额来源

    private var sourceIndex: Int {
        switch state.balanceSource {
        case .auto:       return 0
        case .apiKey:     return 1
        case .webAccount: return 2
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead("余额来源", meta: "SOURCE")

            DSSegmentedScale(
                options: ["自动", "API Key", "网页账号"],
                selectedIndex: sourceIndex
            ) { index in
                guard let picked = [BalanceSource.auto, .apiKey, .webAccount][safe: index] else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    state.balanceSource = picked
                }
            }

            HStack(spacing: 5) {
                Rectangle()
                    .fill(state.activeBalanceSource == nil ? DS.warn : DS.ok)
                    .frame(width: 4, height: 4)
                Text(state.balanceSourceNote)
                    .font(DSFont.text(9))
                    .foregroundStyle(state.activeBalanceSource == nil ? DS.warn : DS.ink2)
            }

            Text(state.balanceSource.detail)
                .font(DSFont.text(8.5))
                .foregroundStyle(DS.ink3)
                .fixedSize(horizontal: false, vertical: true)

            if state.balanceSource == .webAccount && !state.hasOfficialToken {
                HStack(spacing: 8) {
                    Button("网页登录授权") { state.openOfficialLogin() }
                        .buttonStyle(DSPrimaryButtonStyle())
                    Spacer()
                }
            }
        }
        .dsCard(padding: 14)
    }

    // MARK: - 菜单栏图标

    private var menuBarStyleIndex: Int {
        state.menuBarIconStyle == .standard ? 0 : 1
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead("菜单栏", meta: "MENU BAR")

            DSSegmentedScale(
                options: ["常规图标", "显示余额"],
                selectedIndex: menuBarStyleIndex
            ) { index in
                let styles = MenuBarIconStyle.allCases          // wallet, currency, amount
                guard let picked = styles[safe: index] else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    state.menuBarIconStyle = picked
                }
            }

            HStack(spacing: 8) {
                Text("预览")
                    .font(DSFont.text(8.5))
                    .foregroundStyle(DS.ink3)

                HStack(spacing: 3) {
                    if let icon = MenuBarMark.icon(for: state.menuBarIconStyle) {
                        Image(nsImage: icon)
                    }
                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(DSFont.text(13))
                            .monospacedDigit()
                            .foregroundStyle(DS.ink)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(DS.tick)
                .overlay(Rectangle().strokeBorder(DS.rule, lineWidth: 1))

                Spacer()
            }

            Text(state.menuBarIconStyle.detail)
                .font(DSFont.text(8.5))
                .foregroundStyle(DS.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dsCard(padding: 14)
    }

    /// 预览里用真实金额（常规图标不显示金额）
    private var previewText: String {
        state.menuBarText
    }

    // MARK: - API Key

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHead("API Key", meta: state.apiKeyConfigured ? "CONFIGURED" : "MISSING")

            Text("读取 platform.deepseek.com 的余额接口。")
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink3)

            // 下划线输入框
            HStack(spacing: 8) {
                SecureField("sk-...", text: $keyInput)
                    .textFieldStyle(.plain)
                    .font(DSFont.label(11, weight: .regular))
                    .foregroundStyle(DS.ink)
                    .focused($keyFocused)
                    .onSubmit { saveKey() }

                Button {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        keyInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        keyFocused = true
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.ink3)
                }
                .buttonStyle(.plain)
                .help("从剪贴板粘贴")
                .accessibilityLabel("从剪贴板粘贴 API Key")
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(keyFocused ? DS.ink : DS.rule)
                    .frame(height: 1)
            }

            HStack(spacing: 8) {
                Button("保存") { saveKey() }
                    .buttonStyle(DSPrimaryButtonStyle())

                Button("测试连接") { runTest() }
                    .buttonStyle(DSSecondaryButtonStyle())
                    .disabled(isTesting)

                if isTesting {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.62)
                        .frame(width: 12, height: 12)
                }

                if justSaved {
                    Text("SAVED")
                        .font(DSFont.label(8, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(DS.ok)
                }

                Spacer(minLength: 4)

                Link(destination: DeepSeekAPI.platformKeyURL) {
                    HStack(spacing: 2) {
                        Text("获取 Key")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .font(DSFont.text(9.5, weight: .medium))
                    .foregroundStyle(DS.ink2)
                }
            }

            if let result = testResult {
                HStack(spacing: 5) {
                    Rectangle()
                        .fill(result.contains("成功") ? DS.ok : DS.err)
                        .frame(width: 4, height: 4)
                    Text(result)
                        .font(DSFont.text(9))
                        .foregroundStyle(result.contains("成功") ? DS.ok : DS.err)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Hairline(color: DS.ruleSoft)

            HStack(spacing: 6) {
                Text("凭证存于本机 Application Support，权限 600")
                    .font(DSFont.text(8.5))
                    .foregroundStyle(DS.ink3)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if state.apiKeyConfigured {
                    Button("清除") {
                        state.clearApiKey()
                        keyInput = ""
                        justSaved = false
                        testResult = nil
                    }
                    .buttonStyle(.plain)
                    .font(DSFont.text(8.5, weight: .medium))
                    .foregroundStyle(DS.ink3)
                }
            }
        }
        .dsCard(padding: 14)
    }

    // MARK: - 官方用量

    private var officialSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead("官方用量", meta: "PLATFORM")

            officialStateBody

            HStack(spacing: 8) {
                Button("网页登录授权") { state.openOfficialLogin() }
                    .buttonStyle(DSPrimaryButtonStyle())

                if state.hasOfficialToken {
                    Button("刷新") {
                        Task { await state.refreshOfficial() }
                    }
                    .buttonStyle(DSSecondaryButtonStyle())

                    Button("退出") { state.logoutOfficial() }
                        .buttonStyle(DSSecondaryButtonStyle())
                }

                Spacer()
            }

            Text("Token 失效后重新授权即可，不影响余额。")
                .font(DSFont.text(8.5))
                .foregroundStyle(DS.ink3)
        }
        .dsCard(padding: 14)
    }

    private var officialStateText: String {
        switch state.officialState {
        case .ok:            return "SYNCED"
        case .loading:       return "SYNCING"
        case .failed:        return "EXPIRED"
        case .notAuthorized: return "NOT LINKED"
        }
    }

    @ViewBuilder
    private var officialStateBody: some View {
        switch state.officialState {
        case .ok:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    MonoTag(text: "SYNCED")
                    Text(state.officialData.fetchedAt?.formatted(date: .omitted, time: .shortened) ?? "—")
                        .font(DSFont.label(9, weight: .medium))
                        .foregroundStyle(DS.ink2)
                }

                if let message = state.officialMessage {
                    Text(message)
                        .font(DSFont.text(8.5))
                        .foregroundStyle(DS.warn)
                        .lineLimit(2)
                }
            }

        case .loading:
            HStack(spacing: 7) {
                ProgressView().controlSize(.mini).scaleEffect(0.62)
                Text("正在同步官方数据…")
                    .font(DSFont.text(9))
                    .foregroundStyle(DS.ink3)
            }

        case .failed(let message):
            Text(message)
                .font(DSFont.text(9))
                .foregroundStyle(DS.err)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

        case .notAuthorized:
            Text("登录一次即可查看累计消费、请求次数与近 30 天明细。")
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 刷新频率

    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead("自动刷新", meta: "INTERVAL")

            Text("余额与用量共用同一频率，后台静默刷新。")
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink3)

            DSSegmentedScale(
                options: refreshOptions.map(\.label),
                selectedIndex: refreshOptions.firstIndex { $0.value == state.refreshInterval } ?? 2
            ) { index in
                guard let picked = refreshOptions[safe: index] else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    state.refreshInterval = picked.value
                }
            }
        }
        .dsCard(padding: 14)
    }

    // MARK: - 关于

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3"
        return "v\(version)"
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead("关于", meta: versionText)

            HStack(spacing: 10) {
                DSLogo(size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DeepSeekBar")
                        .font(DSFont.text(11, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text("菜单栏余额与用量助手")
                        .font(DSFont.text(8.5))
                        .foregroundStyle(DS.ink3)
                }
                Spacer()
                Button("退出应用") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(DSSecondaryButtonStyle())
            }

            Hairline(color: DS.ruleSoft)

            HStack(spacing: 5) {
                Rectangle().fill(DS.ok).frame(width: 4, height: 4)
                Text("所有数据仅保存在本机")
                    .font(DSFont.text(8.5))
                    .foregroundStyle(DS.ink3)
                Spacer(minLength: 4)
                Link("开放平台", destination: URL(string: "https://platform.deepseek.com")!)
                    .font(DSFont.text(8.5, weight: .medium))
                    .foregroundStyle(DS.ink2)
            }
        }
        .dsCard(padding: 14)
    }

    // MARK: - 动作

    private func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            testResult = "请输入有效的 API Key"
            return
        }
        state.settings.setApiKey(trimmed)
        keyInput = trimmed
        justSaved = true
        testResult = nil
        keyFocused = false

        Task {
            await state.refreshBalanceIfNeeded(force: true)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                justSaved = false
            }
        }
    }

    private func runTest() {
        isTesting = true
        testResult = nil
        Task {
            await state.refreshBalance()
            switch state.status {
            case .ok(let info):
                testResult = "成功：当前余额 ¥\(String(format: "%.2f", info.totalBalance))"
            case .notConfigured:
                testResult = "失败：尚未配置 API Key"
            case .failed(let message), .insufficient(let message):
                testResult = "失败：\(message)"
            case .loading:
                testResult = "测试中…"
            }
            isTesting = false
        }
    }
}

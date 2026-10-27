import SwiftUI
import AppKit

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

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 11) {
                    accountCard
                    officialCard
                    refreshCard
                    aboutCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 14)
            }

            footer
        }
        .frame(width: 380, height: 600)
        .onAppear {
            keyInput = state.settings.apiKey ?? ""
        }
        .onChange(of: state.apiKeyConfigured) { _, configured in
            if !configured { keyInput = "" }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Text("设置")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textPrimary)

            Spacer()

            DSPill(text: "仅存本机", color: DS.green, icon: "lock.fill")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("返回") { onBack() }
                .buttonStyle(DSSecondaryButtonStyle())

            Spacer()

            DSIconButton(systemName: "power", help: "退出 DeepSeekBar", size: 22) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(DS.background)
    }

    // MARK: - API Key

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                settingIcon("key.fill", color: DS.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text("API Key")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text("用于读取账户余额")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer()
                if state.apiKeyConfigured {
                    DSPill(text: "已配置", color: DS.green, icon: "checkmark.circle.fill")
                } else {
                    DSPill(text: "未配置", color: DS.textSecondary, showsDot: true)
                }
            }

            HStack(spacing: 6) {
                SecureField("sk-...", text: $keyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DS.textPrimary)
                    .focused($keyFocused)
                    .onSubmit { saveKey() }

                Button {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        keyInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        keyFocused = true
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10.5))
                        .foregroundStyle(DS.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(DS.card))
                }
                .buttonStyle(.plain)
                .help("从剪贴板粘贴")
                .accessibilityLabel("从剪贴板粘贴 API Key")
            }
            .padding(.leading, 10)
            .padding(.trailing, 4)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.cardSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(keyFocused ? DS.brand.opacity(0.65) : DS.border, lineWidth: keyFocused ? 1.2 : 0.8)
            )

            HStack(spacing: 7) {
                Button("保存 Key") { saveKey() }
                    .buttonStyle(DSPrimaryButtonStyle())

                Button("测试连接") { runTest() }
                    .buttonStyle(DSSecondaryButtonStyle())
                    .disabled(isTesting)

                if isTesting {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.72)
                        .frame(width: 14, height: 14)
                }

                if justSaved {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DS.green)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                Spacer(minLength: 4)

                Link(destination: DeepSeekAPI.platformKeyURL) {
                    HStack(spacing: 2) {
                        Text("获取 API Key")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(DS.brand)
                }
            }

            if let result = testResult {
                Label(result, systemImage: result.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(result.contains("成功") ? DS.green : DS.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Text("凭证保存在本机 Application Support（600 权限）")
                    .font(.system(size: 8.5))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if state.apiKeyConfigured {
                    Button("清除 Key") {
                        state.clearApiKey()
                        keyInput = ""
                        justSaved = false
                        testResult = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(DS.textTertiary)
                }
            }
        }
        .dsCard(padding: 14)
    }

    // MARK: - 官方用量

    private var officialCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                settingIcon("person.badge.key.fill", color: DS.violet)
                VStack(alignment: .leading, spacing: 1) {
                    Text("官方用量")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text("与 platform.deepseek.com 同源")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer()
                officialStatePill
            }

            officialStateBody

            HStack(spacing: 7) {
                Button("网页登录授权") { state.openOfficialLogin() }
                    .buttonStyle(DSPrimaryButtonStyle())

                if state.hasOfficialToken {
                    Button("立即刷新") {
                        Task { await state.refreshOfficial() }
                    }
                    .buttonStyle(DSSecondaryButtonStyle())

                    Button("退出") { state.logoutOfficial() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5))
                        .foregroundStyle(DS.textTertiary)
                }

                Spacer()
            }

            Text("Token 失效后重新授权即可，不影响余额功能。")
                .font(.system(size: 8.5))
                .foregroundStyle(DS.textTertiary)
        }
        .dsCard(padding: 14)
    }

    @ViewBuilder
    private var officialStatePill: some View {
        switch state.officialState {
        case .ok:
            DSPill(text: "已同步", color: DS.green, icon: "checkmark.seal.fill")
        case .loading:
            DSPill(text: "同步中", color: DS.amber, icon: "arrow.triangle.2.circlepath")
        case .failed:
            DSPill(text: "已失效", color: DS.red, icon: "exclamationmark.circle.fill")
        case .notAuthorized:
            DSPill(text: "未授权", color: DS.textSecondary, showsDot: true)
        }
    }

    @ViewBuilder
    private var officialStateBody: some View {
        switch state.officialState {
        case .ok:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 8.5))
                    Text("同步于 \(state.officialData.fetchedAt?.formatted(date: .omitted, time: .shortened) ?? "—")")
                        .font(.system(size: 9))
                }
                .foregroundStyle(DS.textTertiary)

                if let message = state.officialMessage {
                    Label(message, systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 8.5))
                        .foregroundStyle(DS.amber)
                }
            }

        case .loading:
            HStack(spacing: 7) {
                ProgressView().controlSize(.mini).scaleEffect(0.72)
                Text("正在同步官方数据…")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textSecondary)
            }

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(DS.red)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

        case .notAuthorized:
            Text("登录一次即可查看累计消费、请求次数与近 30 天明细。")
                .font(.system(size: 9))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 刷新频率

    private var refreshCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                settingIcon("arrow.clockwise", color: DS.teal)
                VStack(alignment: .leading, spacing: 1) {
                    Text("自动刷新")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text("余额与用量共用同一频率")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer()
            }

            HStack(spacing: 3) {
                ForEach(refreshOptions, id: \.value) { option in
                    let selected = state.refreshInterval == option.value
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            state.refreshInterval = option.value
                        }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 9.5, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? .white : DS.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(selected ? DS.brand : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.cardSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(DS.border.opacity(0.75), lineWidth: 0.7)
            )

            Text("后台静默刷新，不会打断当前操作。")
                .font(.system(size: 8.5))
                .foregroundStyle(DS.textTertiary)
        }
        .dsCard(padding: 14)
    }

    // MARK: - 关于

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3"
        return "v\(version) · 菜单栏余额与用量助手"
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                DSLogo(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DeepSeekBar")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(versionText)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer()
                Button("退出应用") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(DSSecondaryButtonStyle())
            }

            DSDivider()

            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.green)
                Text("所有数据仅保存在本机，不上传第三方")
                    .font(.system(size: 8.5))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Link("开放平台", destination: URL(string: "https://platform.deepseek.com")!)
                    .font(.system(size: 8.5))
                    .foregroundStyle(DS.brand)
            }
        }
        .dsCard(padding: 14)
    }

    // MARK: - 小组件

    private func settingIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.10))
                .frame(width: 30, height: 30)
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
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

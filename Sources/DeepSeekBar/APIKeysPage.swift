import SwiftUI
import AppKit

struct APIKeysPage: View {
    @EnvironmentObject var state: AppState
    var onBack: () -> Void

    @State private var keys: [APIKeyInfo] = []
    @State private var isLoading = false
    @State private var requiresReauth = false
    @State private var loadError: String?

    @State private var showCreate = false
    @State private var newKeyName = ""
    @State private var createdKey: CreatedAPIKey?
    @State private var copiedSecret = false
    @State private var usedCreatedKey = false

    @State private var renameTarget: APIKeyInfo?
    @State private var renameName = ""
    @State private var deleteTarget: APIKeyInfo?

    @State private var isMutating = false
    @State private var actionError: String?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        ZStack {
            pageContent

            if showCreate {
                createOverlay
            }
            if let createdKey {
                createdKeyOverlay(createdKey)
            }
            if let renameTarget {
                renameOverlay(renameTarget)
            }
            if let deleteTarget {
                deleteOverlay(deleteTarget)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if state.officialToken != nil {
                await reload()
            }
        }
        .onChange(of: state.officialToken) { _, token in
            if token != nil {
                Task { await reload() }
            } else {
                keys = []
                requiresReauth = false
                loadError = nil
            }
        }
    }

    // MARK: - 页面主体

    private var pageContent: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    introCard

                    if state.officialToken == nil {
                        authCard
                    } else if requiresReauth {
                        reauthCard
                    } else if isLoading && keys.isEmpty {
                        loadingCard
                    } else if let loadError, keys.isEmpty {
                        errorCard(loadError)
                    } else if keys.isEmpty {
                        emptyCard
                    } else {
                        ForEach(keys) { key in
                            keyCard(key)
                        }
                        footerNote
                    }
                }
                .padding(.bottom, 14)
            }

            pageFooter
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("API 管理")
                    .font(DSFont.text(13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(DS.ink)

                Rectangle()
                    .fill(DS.rule)
                    .frame(width: 14, height: 1)

                Text("API KEYS")
                    .font(DSFont.label(8, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(DS.ink3)

                Spacer()

                if state.officialToken != nil {
                    DSPill(text: "\(keys.count) KEYS", color: DS.ink3, showsDot: false)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            Hairline()
        }
    }

    private var pageFooter: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack(spacing: 8) {
                DSIconButton(systemName: "chevron.left", help: "返回", size: 24, action: onBack)
                Text("返回")
                    .font(DSFont.text(10, weight: .medium))
                    .foregroundStyle(DS.ink2)
                    .onTapGesture { onBack() }

                Spacer()

                if state.officialToken != nil && !requiresReauth {
                    Button("新建") {
                        actionError = nil
                        newKeyName = ""
                        showCreate = true
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                }

                DSIconButton(systemName: "arrow.clockwise", help: "刷新 API Key 列表", size: 24) {
                    Task { await reload() }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHead("平台 API Keys", meta: "PLATFORM")

            Text("创建、重命名或删除 Key；完整 Key 只在创建时显示一次。")
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dsCard(padding: 14)
    }

    private var footerNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Rectangle()
                .fill(DS.warn)
                .frame(width: 4, height: 4)
                .padding(.top, 4)
            Text("删除 Key 后，正在使用该 Key 的程序会立即失效且无法恢复。")
                .font(DSFont.text(8.5))
                .foregroundStyle(DS.ink3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 状态卡片

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHead("尚未授权", meta: "REQUIRED")

            Text("API 管理与官方用量共用网页登录 token，不会读取或上传你的 Key。")
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("网页登录授权") { state.openOfficialLogin() }
                    .buttonStyle(DSPrimaryButtonStyle())
                Spacer()
            }
        }
        .dsCard(padding: 14)
    }

    private var reauthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHead("登录已过期", meta: "EXPIRED")

            HStack(spacing: 8) {
                Button("重新授权") { state.openOfficialLogin() }
                    .buttonStyle(DSPrimaryButtonStyle())
                Button("重试") { Task { await reload() } }
                    .buttonStyle(DSSecondaryButtonStyle())
                Spacer()
            }
        }
        .dsCard(padding: 14)
    }

    private var loadingCard: some View {
        HStack(spacing: 9) {
            ProgressView().controlSize(.mini).scaleEffect(0.65)
            Text("正在读取 API Keys…")
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink3)
            Spacer()
        }
        .dsCard(padding: 16)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHead("读取失败", meta: "ERROR")

            Text(message)
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("重试") { Task { await reload() } }
                    .buttonStyle(DSPrimaryButtonStyle())
                if state.officialToken != nil {
                    Button("重新授权") { state.openOfficialLogin() }
                        .buttonStyle(DSSecondaryButtonStyle())
                }
                Spacer()
            }
        }
        .dsCard(padding: 14)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHead("还没有 API Key", meta: "EMPTY")

            Text("创建一个 Key 后，可一键设为当前余额查询 Key。")
                .font(DSFont.text(9))
                .foregroundStyle(DS.ink2)

            HStack(spacing: 8) {
                Button("创建第一个 Key") {
                    actionError = nil
                    newKeyName = ""
                    showCreate = true
                }
                .buttonStyle(DSPrimaryButtonStyle())
                Spacer()
            }
        }
        .dsCard(padding: 14)
    }

    // MARK: - Key 卡片

    private func keyCard(_ key: APIKeyInfo) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(key.name)
                    .font(DSFont.text(11, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)

                if isCurrentKey(key) {
                    DSPill(text: "当前使用", color: DS.ok, size: 8)
                }
                if key.isHarnessKey {
                    DSPill(text: "DSH", color: DS.violet, size: 8)
                }

                Spacer(minLength: 4)

                if key.canManage {
                    DSIconButton(systemName: "pencil", help: "重命名", size: 22) {
                        actionError = nil
                        renameName = key.name
                        renameTarget = key
                    }
                    DSIconButton(
                        systemName: "trash",
                        help: "删除",
                        tint: DS.ink3,
                        hoverTint: DS.err,
                        size: 22
                    ) {
                        actionError = nil
                        deleteTarget = key
                    }
                }
            }

            Text(key.maskedKey.isEmpty ? "由 DeepSeek Harness 管理" : key.maskedKey)
                .font(DSFont.label(9.5, weight: .regular))
                .foregroundStyle(DS.ink2)
                .lineLimit(1)
                .textSelection(.enabled)

            HStack(spacing: 7) {
                MonoTag(text: "CREATED", size: 7.5)
                Text(formatDate(key.createdAt))
                    .font(DSFont.label(8.5, weight: .regular))
                    .foregroundStyle(DS.ink3)
                Rectangle().fill(DS.rule).frame(width: 8, height: 1)
                Text(key.lastUsed.map { "最近使用 " + formatDate($0) } ?? "从未使用")
                    .font(DSFont.text(8.5))
                    .foregroundStyle(DS.ink3)
                Spacer()
            }
        }
        .dsCard(padding: 12)
    }

    private func isCurrentKey(_ key: APIKeyInfo) -> Bool {
        guard let current = state.settings.apiKey,
              !current.isEmpty,
              !key.maskedKey.isEmpty else { return false }
        return key.maskedKey.hasPrefix(String(current.prefix(8)))
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    // MARK: - 弹层

    private func overlayContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            content()
                .padding(16)
                .frame(width: 330)
                .background(DS.raise)
                .overlay(Rectangle().strokeBorder(DS.rule, lineWidth: 1))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var createOverlay: some View {
        overlayContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("新建 API Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Spacer()
                    DSIconButton(systemName: "xmark", help: "关闭", size: 24) {
                        showCreate = false
                        actionError = nil
                    }
                }

                Text("给 Key 起一个用途名称，例如「DeepSeekBar」「脚本」。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Key 名称", text: $newKeyName)
                    .textFieldStyle(.plain)
                    .font(DSFont.text(11.5))
                    .foregroundStyle(DS.ink)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(DS.ink.opacity(0.35)).frame(height: 1)
                    }
                    .onSubmit { Task { await createKey() } }

                if let actionError {
                    Text(actionError)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if isMutating {
                        ProgressView().controlSize(.mini).scaleEffect(0.75)
                    }
                    Spacer()
                    Button("取消") {
                        showCreate = false
                        actionError = nil
                    }
                    .buttonStyle(DSSecondaryButtonStyle())

                    Button("创建") {
                        Task { await createKey() }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(isMutating || newKeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func createdKeyOverlay(_ created: CreatedAPIKey) -> some View {
        overlayContainer {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.green)
                    Text("API Key 已创建")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Spacer()
                }

                Text("出于安全考虑，完整 Key 只显示这一次，请立即复制保存。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(created.secret)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .textSelection(.enabled)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().strokeBorder(DS.rule, lineWidth: 1))

                HStack(spacing: 7) {
                    Button(copiedSecret ? "已复制" : "复制 Key") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(created.secret, forType: .string)
                        copiedSecret = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copiedSecret = false
                        }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())

                    Button(usedCreatedKey ? "已设为当前 Key" : "设为当前 Key") {
                        state.useAPIKey(created.secret)
                        usedCreatedKey = true
                    }
                    .buttonStyle(DSSecondaryButtonStyle())
                    .disabled(usedCreatedKey)

                    Spacer()
                }

                HStack {
                    Spacer()
                    Button("完成") {
                        createdKey = nil
                        copiedSecret = false
                        usedCreatedKey = false
                    }
                    .buttonStyle(DSSecondaryButtonStyle())
                }
            }
        }
    }

    private func renameOverlay(_ key: APIKeyInfo) -> some View {
        overlayContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("重命名 API Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Spacer()
                    DSIconButton(systemName: "xmark", help: "关闭", size: 24) {
                        renameTarget = nil
                        actionError = nil
                    }
                }

                TextField("新名称", text: $renameName)
                    .textFieldStyle(.plain)
                    .font(DSFont.text(11.5))
                    .foregroundStyle(DS.ink)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(DS.ink.opacity(0.35)).frame(height: 1)
                    }
                    .onSubmit { Task { await renameKey(key) } }

                if let actionError {
                    Text(actionError)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.red)
                }

                HStack(spacing: 8) {
                    if isMutating {
                        ProgressView().controlSize(.mini).scaleEffect(0.75)
                    }
                    Spacer()
                    Button("取消") {
                        renameTarget = nil
                        actionError = nil
                    }
                    .buttonStyle(DSSecondaryButtonStyle())

                    Button("保存") {
                        Task { await renameKey(key) }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(isMutating || renameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func deleteOverlay(_ key: APIKeyInfo) -> some View {
        overlayContainer {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.red)
                    Text("删除 API Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Spacer()
                }

                Text("确定删除「\(key.name)」吗？删除后使用该 Key 的程序会立即失效，且无法恢复。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isCurrentKey(key) {
                    Label("这是 DeepSeekBar 当前用于查询余额的 Key，删除后余额会停止更新。",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionError {
                    Text(actionError)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.red)
                }

                HStack(spacing: 8) {
                    if isMutating {
                        ProgressView().controlSize(.mini).scaleEffect(0.75)
                    }
                    Spacer()
                    Button("取消") {
                        deleteTarget = nil
                        actionError = nil
                    }
                    .buttonStyle(DSSecondaryButtonStyle())

                    Button("确认删除") {
                        Task { await deleteKey(key) }
                    }
                    .buttonStyle(DSPrimaryButtonStyle(color: DS.red))
                    .disabled(isMutating)
                }
            }
        }
    }

    // MARK: - 动作

    private func reload() async {
        guard let token = state.officialToken, !token.isEmpty else {
            keys = []
            requiresReauth = false
            loadError = nil
            return
        }

        isLoading = true
        loadError = nil
        requiresReauth = false

        do {
            let fetched = try await OfficialAPI.fetchAPIKeys(token: token)
            keys = sortKeys(fetched)
        } catch {
            if let apiError = error as? APIError, case .invalidKey = apiError {
                requiresReauth = true
                keys = []
            } else {
                loadError = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func sortKeys(_ items: [APIKeyInfo]) -> [APIKeyInfo] {
        items.sorted { lhs, rhs in
            let lhsCurrent = isCurrentKey(lhs)
            let rhsCurrent = isCurrentKey(rhs)
            if lhsCurrent != rhsCurrent { return lhsCurrent }

            let lhsDate = lhs.lastUsed ?? lhs.createdAt ?? .distantPast
            let rhsDate = rhs.lastUsed ?? rhs.createdAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    private func createKey() async {
        guard let token = state.officialToken, !token.isEmpty else {
            requiresReauth = true
            showCreate = false
            return
        }
        let name = newKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            actionError = "请输入 Key 名称"
            return
        }

        isMutating = true
        actionError = nil

        do {
            let created = try await OfficialAPI.createAPIKey(token: token, name: name)
            showCreate = false
            newKeyName = ""
            createdKey = created
            await reload()
        } catch {
            actionError = error.localizedDescription
        }

        isMutating = false
    }

    private func renameKey(_ key: APIKeyInfo) async {
        guard let token = state.officialToken, !token.isEmpty else {
            requiresReauth = true
            renameTarget = nil
            return
        }
        let name = renameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            actionError = "请输入 Key 名称"
            return
        }

        isMutating = true
        actionError = nil

        do {
            try await OfficialAPI.updateAPIKey(token: token, key: key, name: name)
            keys = keys.map { item in
                guard item.id == key.id else { return item }
                return APIKeyInfo(
                    id: item.id,
                    name: name,
                    maskedKey: item.maskedKey,
                    createdAt: item.createdAt,
                    lastUsed: item.lastUsed,
                    keyType: item.keyType,
                    trackingId: item.trackingId
                )
            }
            renameTarget = nil
        } catch {
            if let apiError = error as? APIError, case .invalidKey = apiError {
                requiresReauth = true
                renameTarget = nil
            } else {
                actionError = error.localizedDescription
            }
        }

        isMutating = false
    }

    private func deleteKey(_ key: APIKeyInfo) async {
        guard let token = state.officialToken, !token.isEmpty else {
            requiresReauth = true
            deleteTarget = nil
            return
        }

        isMutating = true
        actionError = nil

        do {
            try await OfficialAPI.deleteAPIKey(token: token, key: key)
            keys.removeAll { $0.id == key.id }
            deleteTarget = nil
        } catch {
            if let apiError = error as? APIError, case .invalidKey = apiError {
                requiresReauth = true
                deleteTarget = nil
            } else {
                actionError = error.localizedDescription
            }
        }

        isMutating = false
    }
}

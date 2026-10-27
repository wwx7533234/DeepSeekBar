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
        .frame(width: 380, height: 620)
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
                VStack(spacing: 10) {
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
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 14)
            }

            pageFooter
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("API 管理")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textPrimary)

            Spacer()

            if state.officialToken != nil {
                DSPill(text: "\(keys.count) 个 Key", color: DS.textSecondary, showsDot: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var pageFooter: some View {
        HStack(spacing: 8) {
            Button("返回") { onBack() }
                .buttonStyle(DSSecondaryButtonStyle())

            Spacer()

            if state.officialToken != nil && !requiresReauth {
                Button("新建") {
                    actionError = nil
                    newKeyName = ""
                    showCreate = true
                }
                .buttonStyle(DSPrimaryButtonStyle())
            }

            DSIconButton(systemName: "arrow.clockwise", help: "刷新 API Key 列表", size: 22) {
                Task { await reload() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(DS.background)
    }

    private var introCard: some View {
        HStack(alignment: .top, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(DS.brand.opacity(0.10))
                    .frame(width: 30, height: 30)
                Image(systemName: "key.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DeepSeek 平台 API Keys")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Text("创建、重命名或删除 Key；完整 Key 只在创建时显示一次。")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if state.officialToken != nil && !requiresReauth {
                Button("新建") {
                    actionError = nil
                    newKeyName = ""
                    showCreate = true
                }
                .buttonStyle(DSPrimaryButtonStyle())
            }
        }
        .dsCard(padding: 12)
    }

    private var footerNote: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 9))
                .foregroundStyle(DS.amber)
                .padding(.top, 1)
            Text("删除 Key 后，正在使用该 Key 的程序会立即失效且无法恢复。")
                .font(.system(size: 8.5))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - 状态卡片

    private var authCard: some View {
        VStack(spacing: 9) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 22))
                .foregroundStyle(DS.brand)
            Text("先授权官方账号")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.textPrimary)
            Text("API 管理使用与官方用量相同的网页登录 token，不会读取或上传你的 Key。")
                .font(.system(size: 9))
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("网页登录授权") {
                state.openOfficialLogin()
            }
            .buttonStyle(DSPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .dsCard(padding: 14)
    }

    private var reauthCard: some View {
        VStack(spacing: 10) {
            Label("登录已过期，请重新授权", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.red)
            HStack(spacing: 8) {
                Button("重新授权") { state.openOfficialLogin() }
                    .buttonStyle(DSPrimaryButtonStyle())
                Button("重试") { Task { await reload() } }
                    .buttonStyle(DSSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .dsCard(padding: 14)
    }

    private var loadingCard: some View {
        HStack(spacing: 9) {
            ProgressView().controlSize(.small)
            Text("正在读取 API Keys…")
                .font(.system(size: 10))
                .foregroundStyle(DS.textSecondary)
            Spacer()
        }
        .dsCard(padding: 14)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.amber)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("重试") { Task { await reload() } }
                    .buttonStyle(DSPrimaryButtonStyle())
                if state.officialToken != nil {
                    Button("重新授权") { state.openOfficialLogin() }
                        .buttonStyle(DSSecondaryButtonStyle())
                }
            }
        }
        .dsCard(padding: 14)
    }

    private var emptyCard: some View {
        VStack(spacing: 9) {
            Image(systemName: "key")
                .font(.system(size: 22))
                .foregroundStyle(DS.textTertiary)
            Text("还没有 API Key")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(DS.textPrimary)
            Text("创建一个 Key 后，可一键设为当前余额查询 Key。")
                .font(.system(size: 9))
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
            Button("创建第一个 Key") {
                actionError = nil
                newKeyName = ""
                showCreate = true
            }
            .buttonStyle(DSPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .dsCard(padding: 14)
    }

    // MARK: - Key 卡片

    private func keyCard(_ key: APIKeyInfo) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(key.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)

                if isCurrentKey(key) {
                    DSPill(text: "当前使用", color: DS.green, icon: "checkmark.circle.fill", size: 8.5)
                }
                if key.isHarnessKey {
                    DSPill(text: "DSH", color: DS.violet, icon: "link", size: 8.5)
                }

                Spacer(minLength: 4)

                if key.canManage {
                    DSIconButton(systemName: "pencil", help: "重命名", size: 23) {
                        actionError = nil
                        renameName = key.name
                        renameTarget = key
                    }
                    DSIconButton(
                        systemName: "trash",
                        help: "删除",
                        tint: DS.red.opacity(0.75),
                        hoverTint: DS.red,
                        hoverFill: DS.red.opacity(0.10),
                        size: 23
                    ) {
                        actionError = nil
                        deleteTarget = key
                    }
                }
            }

            Text(key.maskedKey.isEmpty ? "由 DeepSeek Harness 管理" : key.maskedKey)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(DS.textSecondary)
                .lineLimit(1)
                .textSelection(.enabled)

            HStack(spacing: 5) {
                Text("创建 \(formatDate(key.createdAt))")
                Text("·").opacity(0.5)
                Text(key.lastUsed.map { "最近使用 \(formatDate($0))" } ?? "从未使用")
                Spacer()
            }
            .font(.system(size: 8.5))
            .foregroundStyle(DS.textTertiary)
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
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            content()
                .padding(14)
                .frame(width: 330)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DS.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DS.border, lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.20), radius: 24, x: 0, y: 12)
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
                    .font(.system(size: 11.5))
                    .foregroundStyle(DS.textPrimary)
                    .padding(9)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(DS.cardSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(DS.border, lineWidth: 0.8)
                    )
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
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(DS.cardSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(DS.border, lineWidth: 0.8)
                    )

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
                    .font(.system(size: 11.5))
                    .foregroundStyle(DS.textPrimary)
                    .padding(9)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(DS.cardSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(DS.border, lineWidth: 0.8)
                    )
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

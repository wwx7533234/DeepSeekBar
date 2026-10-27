import Foundation
import Combine

enum BalanceStatus: Equatable {
    case notConfigured
    case loading
    case ok(BalanceInfo)
    case failed(String)
    case insufficient(String)
}

enum OfficialState: Equatable {
    case notAuthorized
    case loading
    case ok
    case failed(String)
}

@MainActor
final class AppState: ObservableObject {
    // 单一数据源：@Published 即真相，didSet 里完成持久化与副作用
    @Published var status: BalanceStatus = .notConfigured
    @Published var lastUpdated: Date?
    /// 最近一次成功获取的余额：刷新期间菜单栏数字不闪断。
    @Published private(set) var lastBalance: BalanceInfo?

    @Published var refreshInterval: TimeInterval {
        didSet {
            settings.refreshInterval = refreshInterval
            startRefreshLoop()
        }
    }

    @Published private(set) var officialData = OfficialUsageData()
    @Published var officialState: OfficialState = .notAuthorized
    @Published private(set) var officialToken: String?
    @Published var officialMessage: String?

    let settings = SettingsStore()

    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        officialToken = KeychainStore.officialToken
        refreshInterval = settings.refreshInterval

        startRefreshLoop()
        Task { await refreshBalanceIfNeeded(force: true) }
        if officialToken != nil {
            Task { await refreshOfficial() }
        }
        if CommandLine.arguments.contains("--webauth") {
            // 调试：启动即弹出官方授权窗口
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.openOfficialLogin()
            }
        }
    }

    // MARK: - 余额

    var apiKeyConfigured: Bool { settings.apiKey != nil }

    var isRefreshing: Bool {
        if case .loading = status { return true }
        if case .loading = officialState { return true }
        return false
    }

    func clearApiKey() {
        KeychainStore.delete()
        lastBalance = nil
        lastUpdated = nil
        status = .notConfigured
    }

    /// API 管理页把新建的 Key 设为当前余额查询 Key。
    func useAPIKey(_ key: String) {
        settings.setApiKey(key)
        Task { await refreshBalanceIfNeeded(force: true) }
    }

    func refreshBalanceIfNeeded(force: Bool, silent: Bool = false) async {
        guard let key = settings.apiKey, !key.isEmpty else {
            status = .notConfigured
            return
        }
        if !force {
            if case .ok = status,
               let last = lastUpdated,
               Date().timeIntervalSince(last) < 60 {
                return
            }
        }
        await refreshBalance(key: key, silent: silent)
    }

    func refreshBalance(silent: Bool = false) async {
        guard let key = settings.apiKey, !key.isEmpty else {
            status = .notConfigured
            return
        }
        await refreshBalance(key: key, silent: silent)
    }

    /// 面板右上角手动刷新：余额 + 官方用量一起更新。
    func refreshAll() async {
        await refreshBalance()
        if officialToken != nil {
            await refreshOfficial()
        }
    }

    // MARK: - 充值

    /// 离开充值页 / 支付完成后调用：到账可能有延迟，连续刷三次余额，再同步官方用量。
    func refreshAfterRecharge() async {
        for attempt in 0..<3 {
            await refreshBalance(silent: true)
            if attempt < 2 {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
        if officialToken != nil {
            await refreshOfficial(silent: true)
        }
    }

    private func refreshBalance(key: String, silent: Bool) async {
        if !silent { status = .loading }
        do {
            let info = try await DeepSeekAPI.fetchBalance(apiKey: key)
            lastBalance = info
            if info.isAvailable {
                status = .ok(info)
            } else {
                status = .insufficient("账户不可用，请检查 DeepSeek 平台")
            }
            lastUpdated = Date()
        } catch {
            // 后台静默刷新失败时保留上一次成功数据，不打断面板展示。
            if !silent || lastBalance == nil {
                status = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - 菜单栏标题

    var menuBarTitle: String {
        guard let info = lastBalance else { return "" }
        return Self.shortBalance(info.totalBalance)
    }

    static func shortBalance(_ v: Double) -> String {
        if v >= 100 { return String(format: "¥%.0f", v) }
        if v >= 10  { return String(format: "¥%.1f", v) }
        return String(format: "¥%.2f", v)
    }

    // MARK: - 官方用量（网页数据）

    var hasOfficialToken: Bool { officialToken != nil }

    /// 拉取官方用量：用户概览 + 近30天费用/tokens
    /// silent=true 用于定时自动刷新（不切 loading 态，避免面板闪烁）
    func refreshOfficial(silent: Bool = false) async {
        guard let token = officialToken, !token.isEmpty else {
            officialState = .notAuthorized
            return
        }
        if !silent { officialState = .loading }
        do {
            let summary = try await OfficialAPI.fetchSummary(token: token)

            // 与网页一致：start/end 按 UTC 零点对齐，tz=0
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(identifier: "UTC")!
            let todayUTC = utcCal.startOfDay(for: Date())
            let start = Int(todayUTC.addingTimeInterval(-29 * 86400).timeIntervalSince1970)
            let end = Int(todayUTC.addingTimeInterval(86400).timeIntervalSince1970)
            let (costDays, costModels, _) = try await OfficialAPI.fetchUsage(token: token, kind: "cost", start: start, end: end, tz: 0)
            let (amountDays, _, totalRequests) = try await OfficialAPI.fetchUsage(token: token, kind: "amount", start: start, end: end, tz: 0)

            var data = OfficialUsageData()
            data.summary = summary
            data.summary.monthlyUsage = costDays.reduce(0) { $0 + $1.1 }          // 近30天消费
            data.summary.totalRequestCount = totalRequests
            data.summary.totalTokens = amountDays.reduce(0) { $0 + $1.1 }         // 近30天 tokens
            data.dailyCost = costDays.map { OfficialDailyPoint(date: Date(timeIntervalSince1970: TimeInterval($0.0)), amount: $0.1) }
            data.dailyAmount = amountDays.map { OfficialDailyPoint(date: Date(timeIntervalSince1970: TimeInterval($0.0)), amount: $0.1) }
            data.models = costModels
            data.fetchedAt = Date()
            officialData = data
            officialState = .ok
            officialMessage = nil
        } catch {
            let message: String
            if let apiErr = error as? APIError, case .invalidKey = apiErr {
                message = "登录已过期，请重新授权"
            } else {
                message = error.localizedDescription
            }

            // 后台静默刷新失败时保留旧数据，避免面板在成功/错误态之间闪烁。
            if silent, officialData.fetchedAt != nil {
                officialMessage = "后台同步失败，当前展示上次数据"
            } else {
                officialState = .failed(message)
            }
        }
    }

    /// 弹出网页登录授权窗口（扫码/验证码），成功后自动拉数据
    func openOfficialLogin() {
        WebAuthController.shared.presentLogin { [weak self] token in
            guard let self else { return }
            KeychainStore.saveOfficialToken(token)
            self.officialToken = token
            self.officialMessage = "授权成功，正在同步官方数据…"
            Task { await self.refreshOfficial() }
        }
    }

    func logoutOfficial() {
        KeychainStore.deleteOfficialToken()
        officialToken = nil
        officialData = OfficialUsageData()
        officialState = .notAuthorized
        officialMessage = nil
    }

    // MARK: - 定时刷新（余额 + 官方用量，同一频率）

    private func startRefreshLoop() {
        refreshTask?.cancel()
        let interval = settings.refreshInterval
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.refreshBalanceIfNeeded(force: false, silent: true)
                if self?.officialToken != nil {
                    await self?.refreshOfficial(silent: true)
                }
            }
        }
    }
}

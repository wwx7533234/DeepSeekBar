import Foundation

// MARK: - 余额模型（DeepSeek /user/balance 响应）

struct BalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [RawBalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

struct RawBalanceInfo: Codable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

struct BalanceInfo: Codable, Equatable {
    let isAvailable: Bool
    let currency: String
    let totalBalance: Double
    let grantedBalance: Double
    let toppedUpBalance: Double
}

// MARK: - 官方用量模型（platform.deepseek.com 网页接口）

/// 余额来源：决定菜单栏数字和余额卡从哪里取数
enum BalanceSource: String, CaseIterable, Codable {
    case auto
    case apiKey
    case webAccount

    var label: String {
        switch self {
        case .auto:       return "自动"
        case .apiKey:     return "API Key"
        case .webAccount: return "网页账号"
        }
    }

    var detail: String {
        switch self {
        case .auto:       return "优先用网页账号的钱包余额，未登录或过期时回落到 API Key"
        case .apiKey:     return "调用 /user/balance，只需填一次、不会过期"
        case .webAccount: return "读取网页账号里的钱包余额，需要保持网页登录"
        }
    }
}

/// 菜单栏图标样式
enum MenuBarIconStyle: String, CaseIterable, Codable {
    case standard    // 常规图标：只显示图标，不显示金额
    case amount      // 显示余额：只显示 ¥ 金额，不显示图标

    var label: String {
        switch self {
        case .standard: return "常规图标"
        case .amount:   return "显示余额"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "只显示一个图标，界面更安静；金额在面板里看"
        case .amount:   return "直接在菜单栏显示 ¥ 金额，不占图标位置"
        }
    }
}

struct OfficialSummary: Codable {
    var currentToken: Double = 0          // 当前余额（充值+赠送钱包之和）
    var toppedUpBalance: Double = 0       // 充值钱包余额
    var grantedBalance: Double = 0        // 赠送钱包余额
    var totalUsage: Double = 0            // 累计消费
    var monthlyUsage: Double = 0          // 近30天消费（由 cost 序列聚合）
    var totalRequestCount: Int = 0        // 近30天请求次数（由 amount 序列聚合）
    var totalTokens: Double = 0           // 近30天 tokens（由 amount 序列聚合）
}

struct OfficialDailyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double    // tokens 或 费用
}

struct OfficialUsageData {
    var summary = OfficialSummary()
    var dailyCost: [OfficialDailyPoint] = []     // 近30天每日费用
    var dailyAmount: [OfficialDailyPoint] = []   // 近30天每日 tokens
    var models: [String: Double] = [:]           // 模型 -> 消费金额
    var fetchedAt: Date?
}

// MARK: - API Key 管理（platform.deepseek.com/api_keys）

struct APIKeyInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let maskedKey: String
    let createdAt: Date?
    let lastUsed: Date?
    let keyType: String
    let trackingId: String

    var isHarnessKey: Bool { keyType == "DSH" }
    var canManage: Bool { !isHarnessKey && !maskedKey.isEmpty }
}

struct CreatedAPIKey: Equatable {
    let name: String
    let secret: String
    let createdAt: Date?
    let trackingId: String
}

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

struct OfficialSummary: Codable {
    var currentToken: Double = 0          // 当前余额（充值+赠送钱包之和）
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

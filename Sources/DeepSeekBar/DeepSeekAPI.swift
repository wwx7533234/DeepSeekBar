import Foundation

enum APIError: LocalizedError {
    case invalidKey
    case rateLimited
    case server(status: Int)
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidKey:   return "API Key 无效或已过期"
        case .rateLimited:  return "请求过于频繁，请稍后重试"
        case .server(let s): return "DeepSeek 服务异常（HTTP \(s)）"
        case .offline:      return "网络连接失败"
        }
    }
}

enum DeepSeekAPI {
    static let apiBase = "https://api.deepseek.com"
    static let balanceURL = URL(string: "\(apiBase)/user/balance")!
    static let platformKeyURL = PlatformWeb.apiKeysURL

    static func fetchBalance(apiKey: String) async throws -> BalanceInfo {
        // 测试/自托管可覆盖上游（DSBAR_UPSTREAM 环境变量）
        let base = ProcessInfo.processInfo.environment["DSBAR_UPSTREAM"] ?? apiBase
        guard let url = URL(string: "\(base)/user/balance") else { throw APIError.offline }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.offline }
        switch http.statusCode {
        case 200: break
        case 401: throw APIError.invalidKey
        case 429: throw APIError.rateLimited
        default:  throw APIError.server(status: http.statusCode)
        }

        let wrapper = try JSONDecoder().decode(BalanceResponse.self, from: data)
        let first = wrapper.balanceInfos.first
        let info = wrapper.balanceInfos.first(where: { $0.currency == "CNY" }) ?? first
        guard let info else { throw APIError.server(status: 200) }

        return BalanceInfo(
            isAvailable: wrapper.isAvailable,
            currency: info.currency,
            totalBalance: Double(info.totalBalance) ?? 0,
            grantedBalance: Double(info.grantedBalance) ?? 0,
            toppedUpBalance: Double(info.toppedUpBalance) ?? 0
        )
    }
}

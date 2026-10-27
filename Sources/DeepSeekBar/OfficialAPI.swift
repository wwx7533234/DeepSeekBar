import Foundation

/// DeepSeek 官方平台内部接口（platform.deepseek.com 网页版同款）
/// 说明：官方公开 API 只有 /user/balance；用量数据来自网页前端调用的内部接口。
/// 这些接口需要网页登录 token（Authorization header）+ 浏览器 UA 才能过 WAF。
enum OfficialAPI {
    static let base = ProcessInfo.processInfo.environment["DSBAR_UPSTREAM"] ?? "https://platform.deepseek.com"

    /// 模拟浏览器请求头（WAF 需要）
    private static func makeRequest(_ path: String, query: [String: String] = [:], token: String) -> URLRequest {
        var comps = URLComponents(string: base + path)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 20
        req.setValue(token, forHTTPHeaderField: "Authorization")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("https://platform.deepseek.com/usage", forHTTPHeaderField: "Referer")
        req.setValue("https://platform.deepseek.com", forHTTPHeaderField: "Origin")
        return req
    }

    /// 统一解析 {code, msg, data:{biz_data: ...}} 包装
    private static func bizData(_ data: Data) throws -> [String: Any] {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.server(status: 0)
        }
        if let code = obj["code"] as? Int, code != 0 {
            let msg = obj["msg"] as? String ?? "未知错误"
            if code == 40002 || code == 40003 {
                throw APIError.invalidKey // token 失效
            }
            throw NSError(domain: "OfficialAPI", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "DeepSeek: \(msg)"])
        }
        guard let data = obj["data"] as? [String: Any],
              let biz = data["biz_data"] as? [String: Any] else {
            throw NSError(domain: "OfficialAPI", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "响应格式异常"])
        }
        return biz
    }

    /// GET /api/v0/users/get_user_summary —— 余额与用量概览（真实结构 2026-08）
    /// biz_data: { normal_wallets:[{currency,balance,token_estimation}], bonus_wallets:[...], total_costs:[{currency,amount}] }
    static func fetchSummary(token: String) async throws -> OfficialSummary {
        var req = makeRequest("/api/v0/users/get_user_summary", token: token)
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.offline }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode)
        }
        let biz = try bizData(data)

        func cnyFirst(_ arr: [[String: Any]]) -> [String: Any]? {
            arr.first { ($0["currency"] as? String) == "CNY" } ?? arr.first
        }
        func asDouble(_ v: Any?) -> Double {
            if let d = v as? Double { return d }
            if let i = v as? Int { return Double(i) }
            if let s = v as? String { return Double(s) ?? 0 }
            return 0
        }

        let wallets = (biz["normal_wallets"] as? [[String: Any]]) ?? []
        let bonus = (biz["bonus_wallets"] as? [[String: Any]]) ?? []
        let costs = (biz["total_costs"] as? [[String: Any]]) ?? []

        var s = OfficialSummary()
        if let w = cnyFirst(wallets) { s.currentToken += asDouble(w["balance"]) }
        if let b = cnyFirst(bonus) { s.currentToken += asDouble(b["balance"]) }
        if let c = cnyFirst(costs) { s.totalUsage = asDouble(c["amount"]) }
        return s
    }

    /// GET /api/v0/usage/by_api_key/{cost|amount}?start=&end=&tz=  （真实结构 2026-08）
    /// cost:   biz_data.data[].series[]，bucket 有 cost:"0.35"
    /// amount: biz_data.series[]，bucket 有 usage:{RESPONSE_TOKEN,REQUEST,PROMPT_CACHE_HIT_TOKEN,PROMPT_CACHE_MISS_TOKEN}
    /// 参数：start/end 为 UTC 零点对齐的 Unix 秒，tz 传 0（与网页一致）
    static func fetchUsage(token: String, kind: String, start: Int, end: Int, tz: Int) async throws
        -> (days: [(Int, Double)], models: [String: Double], requests: Int) {
        let path = "/api/v0/usage/by_api_key/\(kind)"
        var req = makeRequest(path, query: [
            "start": String(start), "end": String(end), "tz": String(tz)
        ], token: token)
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.server(status: (resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let biz = try bizData(data)

        var days: [(Int, Double)] = []
        var models: [String: Double] = [:]
        var totalRequests = 0

        func asDouble(_ v: Any?) -> Double {
            if let d = v as? Double { return d }
            if let i = v as? Int { return Double(i) }
            if let s = v as? String { return Double(s) ?? 0 }
            return 0
        }
        func bucketTime(_ b: [String: Any]) -> Int {
            for k in ["time", "timestamp", "ts", "date"] {
                if let v = b[k] as? Int { return v }
                if let v = b[k] as? Double { return Int(v) }
            }
            return 0
        }
        func parseSeries(_ list: [[String: Any]]) {
            for group in list {
                let model = group["model"] as? String ?? "unknown"
                guard let buckets = group["buckets"] as? [[String: Any]] else { continue }
                for b in buckets {
                    let t = bucketTime(b)
                    var v: Double = 0
                    var req = 0
                    if let cost = b["cost"] {
                        v = asDouble(cost)
                    } else if let usage = b["usage"] as? [String: Any] {
                        req = (usage["REQUEST"] as? NSNumber)?.intValue ?? 0
                        let rt = (usage["RESPONSE_TOKEN"] as? NSNumber)?.intValue ?? 0
                        let hit = (usage["PROMPT_CACHE_HIT_TOKEN"] as? NSNumber)?.intValue ?? 0
                        let miss = (usage["PROMPT_CACHE_MISS_TOKEN"] as? NSNumber)?.intValue ?? 0
                        v = Double(rt + hit + miss)
                    }
                    if t > 0 { days.append((t, v)) }
                    models[model, default: 0] += v
                    totalRequests += req
                }
            }
        }

        // cost: data[].series[]；amount: series[]
        if let dataArr = biz["data"] as? [[String: Any]] {
            for g in dataArr {
                if let series = g["series"] as? [[String: Any]] {
                    parseSeries(series)
                }
            }
        }
        if let series = biz["series"] as? [[String: Any]] {
            parseSeries(series)
        }
        return (days, models, totalRequests)
    }

    // MARK: - API Key 管理

    /// GET /api/v0/users/get_api_keys
    static func fetchAPIKeys(token: String) async throws -> [APIKeyInfo] {
        var req = makeRequest("/api/v0/users/get_api_keys", token: token)
        req.httpMethod = "GET"
        req.setValue("https://platform.deepseek.com/api_keys", forHTTPHeaderField: "Referer")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.offline }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode)
        }

        let biz = try apiKeyEnvelope(data)
        let rows = biz["api_keys"] as? [[String: Any]] ?? []

        return rows.compactMap { row in
            guard let name = row["name"] as? String else { return nil }
            let masked = row["sensitive_id"] as? String ?? ""
            let tracking = row["tracking_id"] as? String ?? ""
            let keyType = row["key_type"] as? String ?? "NORMAL"
            let created = platformDate(row["created_at"])
            let lastUsed = platformDate(row["last_use"])
            let id = tracking.isEmpty
                ? "\(name)-\(created?.timeIntervalSince1970 ?? 0)"
                : tracking

            return APIKeyInfo(
                id: id,
                name: name,
                maskedKey: masked,
                createdAt: created,
                lastUsed: lastUsed,
                keyType: keyType,
                trackingId: tracking
            )
        }
    }

    /// POST /api/v0/users/edit_api_keys action=create
    static func createAPIKey(token: String, name: String) async throws -> CreatedAPIKey {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIKeyError.invalidName }
        guard trimmed.count <= 50 else { throw APIKeyError.nameTooLong }

        let body: [String: Any] = [
            "action": "create",
            "name": trimmed,
            "redacted_key": NSNull(),
            "created_at": NSNull(),
            "tracking_id": NSNull()
        ]
        let biz = try await apiKeyMutation(token: token, body: body)

        guard let apiKey = biz["api_key"] as? [String: Any],
              let secret = apiKey["sensitive_id"] as? String,
              !secret.isEmpty else {
            throw APIKeyError.server(code: -1, message: "创建成功但未返回 Key，请刷新列表查看")
        }

        return CreatedAPIKey(
            name: apiKey["name"] as? String ?? trimmed,
            secret: secret,
            createdAt: platformDate(apiKey["created_at"]),
            trackingId: apiKey["tracking_id"] as? String ?? ""
        )
    }

    /// POST /api/v0/users/edit_api_keys action=update
    static func updateAPIKey(token: String, key: APIKeyInfo, name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIKeyError.invalidName }
        guard trimmed.count <= 50 else { throw APIKeyError.nameTooLong }
        guard key.canManage else { throw APIKeyError.server(code: -1, message: "该 Key 不支持在 App 内重命名") }

        let body: [String: Any] = [
            "action": "update",
            "name": trimmed,
            "redacted_key": key.maskedKey,
            "created_at": Int(key.createdAt?.timeIntervalSince1970 ?? 0),
            "tracking_id": key.trackingId.isEmpty ? NSNull() : key.trackingId
        ]
        _ = try await apiKeyMutation(token: token, body: body)
    }

    /// POST /api/v0/users/edit_api_keys action=delete
    static func deleteAPIKey(token: String, key: APIKeyInfo) async throws {
        guard key.canManage else { throw APIKeyError.server(code: -1, message: "该 Key 不支持在 App 内删除") }

        let body: [String: Any] = [
            "action": "delete",
            "name": NSNull(),
            "redacted_key": key.maskedKey,
            "created_at": Int(key.createdAt?.timeIntervalSince1970 ?? 0),
            "tracking_id": key.trackingId.isEmpty ? NSNull() : key.trackingId
        ]
        _ = try await apiKeyMutation(token: token, body: body)
    }

    private static func apiKeyMutation(token: String, body: [String: Any]) async throws -> [String: Any] {
        var req = makeRequest("/api/v0/users/edit_api_keys", token: token)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("https://platform.deepseek.com/api_keys", forHTTPHeaderField: "Referer")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.offline }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode)
        }
        return try apiKeyEnvelope(data)
    }

    /// API Key 接口的包装：{code,msg,data:{biz_code,biz_msg,biz_data}}
    private static func apiKeyEnvelope(_ data: Data) throws -> [String: Any] {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.server(status: 0)
        }

        if let code = intValue(obj["code"]), code != 0 {
            if code == 40002 || code == 40003 { throw APIError.invalidKey }
            let message = obj["msg"] as? String ?? "未知错误"
            throw NSError(domain: "OfficialAPI", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "DeepSeek: \(message)"])
        }

        guard let dataObj = obj["data"] as? [String: Any] else {
            throw NSError(domain: "OfficialAPI", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "响应格式异常"])
        }

        let bizCode = intValue(dataObj["biz_code"]) ?? 0
        let bizMessage = dataObj["biz_msg"] as? String ?? ""
        switch bizCode {
        case 0:
            break
        case 1:
            throw APIKeyError.limitReached
        case 2:
            throw APIKeyError.nameTooLong
        case 8:
            throw APIKeyError.identityVerificationRequired
        default:
            throw APIKeyError.server(code: bizCode, message: bizMessage)
        }

        return dataObj["biz_data"] as? [String: Any] ?? [:]
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func platformDate(_ value: Any?) -> Date? {
        let seconds: Double?
        if let string = value as? String {
            seconds = Double(string)
        } else if let number = value as? NSNumber {
            seconds = number.doubleValue
        } else {
            seconds = nil
        }
        guard let seconds, seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

enum APIKeyError: LocalizedError {
    case invalidName
    case limitReached
    case nameTooLong
    case identityVerificationRequired
    case server(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "请输入 API Key 名称"
        case .limitReached:
            return "API Key 数量已达上限，请先删除不用的 Key"
        case .nameTooLong:
            return "API Key 名称过长（最多 50 个字符）"
        case .identityVerificationRequired:
            return "需要先完成实名认证才能创建 API Key"
        case .server(_, let message):
            return message.isEmpty ? "API Key 操作失败，请稍后重试" : message
        }
    }
}

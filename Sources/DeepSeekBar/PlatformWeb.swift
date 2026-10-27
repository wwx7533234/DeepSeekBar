import Foundation

/// DeepSeek 开放平台网页入口（与 App 内嵌页面 / 授权窗口共用）。
enum PlatformWeb {
    static let baseURL = URL(string: "https://platform.deepseek.com")!
    static let usageURL = URL(string: "https://platform.deepseek.com/usage")!
    static let apiKeysURL = URL(string: "https://platform.deepseek.com/api_keys")!
    static let topUpURL = URL(string: "https://platform.deepseek.com/top_up")!
    static let signInURL = URL(string: "https://platform.deepseek.com/sign_in")!
}

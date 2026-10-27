import Foundation
import Security

/// 凭证存储（API Key / 官方登录 Token）
///
/// 早期用 Keychain，但本 App 每次打包是 adhoc 签名、签名会变化，
/// 导致 Keychain ACL 不匹配 → 每次读取都弹「输入电脑密码授权」框，体验极差。
/// 已迁移为本地文件存储（Application Support/DeepSeekBar/credentials.json，权限 0600）：
/// 本机单用户场景安全性足够；保留旧 Keychain 条目做一次性迁移。
enum KeychainStore {
    private static let apiKeyAccount = "api_key"
    private static let officialTokenAccount = "official_token"

    private static let fileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("DeepSeekBar/credentials.json")

    // MARK: - 文件存储

    private static func fileLoad(_ key: String) -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return nil }
        return d[key]
    }

    private static func fileSave(_ key: String, _ value: String) {
        var d: [String: String] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            d = existing
        }
        d[key] = value
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted]) {
            try? data.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        }
    }

    private static func fileDelete(_ key: String) {
        guard let data = try? Data(contentsOf: fileURL),
              var d = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
        d.removeValue(forKey: key)
        if let data = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted]) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - 旧 Keychain（一次性迁移）

    private static let legacyService = "com.dsbar.deepseek"

    private static func secLoad(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func secDelete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - 对外 API

    static func save(_ value: String, account: String = apiKeyAccount) {
        fileSave(account, value)
        // 顺带清掉旧 Keychain 条目，避免残留
        secDelete(account)
    }

    static func load(account: String = apiKeyAccount) -> String? {
        if let v = fileLoad(account) { return v }
        // 迁移旧 Keychain 数据
        if let legacy = secLoad(account) {
            fileSave(account, legacy)
            secDelete(account)
            return legacy
        }
        return nil
    }

    static func delete(account: String = apiKeyAccount) {
        fileDelete(account)
        secDelete(account)
    }

    // 官方网页登录 token
    static var officialToken: String? { load(account: officialTokenAccount) }
    static func saveOfficialToken(_ t: String) { save(t, account: officialTokenAccount) }
    static func deleteOfficialToken() { delete(account: officialTokenAccount) }
}

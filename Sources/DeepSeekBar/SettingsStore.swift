import Foundation

/// 本地设置（UserDefaults 持久化；API Key 走本地凭证文件）
final class SettingsStore {
    var refreshInterval: TimeInterval {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    init() {
        let d = UserDefaults.standard
        let saved = d.object(forKey: "refreshInterval") as? TimeInterval
        refreshInterval = saved ?? 300
    }

    var apiKey: String? { KeychainStore.load() }

    func setApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed)
    }
}

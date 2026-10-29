import Foundation

/// 本地设置（UserDefaults 持久化；API Key 走本地凭证文件）
final class SettingsStore {
    var refreshInterval: TimeInterval {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    var menuBarIconStyle: MenuBarIconStyle {
        didSet { UserDefaults.standard.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle") }
    }

    var balanceSource: BalanceSource {
        didSet { UserDefaults.standard.set(balanceSource.rawValue, forKey: "balanceSource") }
    }

    init() {
        let d = UserDefaults.standard
        let saved = d.object(forKey: "refreshInterval") as? TimeInterval
        refreshInterval = saved ?? 300
        balanceSource = BalanceSource(rawValue: d.string(forKey: "balanceSource") ?? "") ?? .auto
        // 旧版本存过 currency（已删除的选项），统一迁到「显示余额」
        let rawStyle = d.string(forKey: "menuBarIconStyle") ?? ""
        menuBarIconStyle = MenuBarIconStyle(rawValue: rawStyle)
            ?? (rawStyle == "currency" ? .amount : .standard)
    }

    var apiKey: String? { KeychainStore.load() }

    func setApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed)
    }
}

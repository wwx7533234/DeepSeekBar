import SwiftUI

struct RechargePage: View {
    @EnvironmentObject var state: AppState
    var onBack: () -> Void

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadID = UUID()
    @State private var justToppedUp = false

    var body: some View {
        VStack(spacing: 10) {
            header
            balanceRow

            webCard

            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: 380, height: 620)
        .task {
            // 支付页面停留期间每 8 秒刷新一次余额，到账后即时反馈。
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { break }
                await state.refreshBalance(silent: true)
            }
        }
        .onChange(of: state.lastBalance?.totalBalance) { old, new in
            guard let old, let new, new > old + 0.001 else { return }
            withAnimation(.easeOut(duration: 0.20)) {
                justToppedUp = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                withAnimation(.easeOut(duration: 0.20)) {
                    justToppedUp = false
                }
            }
        }
        .onDisappear {
            Task { await state.refreshAfterRecharge() }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Text("充值")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textPrimary)

            Spacer()

            if justToppedUp {
                DSPill(text: "余额已更新", color: DS.green, icon: "checkmark.circle.fill")
            } else {
                DSPill(text: "官方充值", color: DS.brand, icon: "shield.lefthalf.filled")
            }
        }
    }

    // MARK: - 当前余额

    private var balanceRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("当前余额")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textTertiary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(currencySymbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.textSecondary)
                    Text(String(format: "%.2f", state.lastBalance?.totalBalance ?? 0))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DS.textPrimary)
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("支付完成后")
                    .font(.system(size: 8.5))
                    .foregroundStyle(DS.textTertiary)
                Text("余额自动刷新")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DS.border, lineWidth: 0.8)
        )
    }

    private var currencySymbol: String {
        switch (state.lastBalance?.currency ?? "CNY").uppercased() {
        case "USD": return "$"
        case "CNY", "RMB": return "¥"
        default: return state.lastBalance?.currency ?? "¥"
        }
    }

    // MARK: - 官方充值页

    private var webCard: some View {
        ZStack {
            RechargeWebView(isLoading: $isLoading, errorMessage: $errorMessage)
                .id(reloadID)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(11)
                    .background(.regularMaterial, in: Circle())
                    .allowsHitTesting(false)
            }

            if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 18))
                        .foregroundStyle(DS.amber)
                    Text("充值页加载失败")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(errorMessage)
                        .font(.system(size: 8.5))
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    Button("重试") {
                        reloadID = UUID()
                        isLoading = true
                        self.errorMessage = nil
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                }
                .padding(16)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DS.border, lineWidth: 0.8)
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - 底部

    private var footer: some View {
        HStack(spacing: 8) {
            Button("返回") { onBack() }
                .buttonStyle(DSSecondaryButtonStyle())

            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 8.5))
                .foregroundStyle(DS.green)
            Text("官方支付")
                .font(.system(size: 8.5))
                .foregroundStyle(DS.textTertiary)

            Button("刷新余额") {
                Task { await state.refreshBalance(silent: true) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(DS.brand)

            DSIconButton(systemName: "arrow.clockwise", help: "重新加载充值页", size: 22) {
                reloadID = UUID()
                isLoading = true
                errorMessage = nil
            }
        }
        .padding(.horizontal, 3)
    }
}

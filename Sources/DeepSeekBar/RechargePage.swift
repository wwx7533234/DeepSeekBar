import SwiftUI

/// 充值 · 官方页面内嵌在纸面里：上方余额读数，下方网页，四周只有发丝线。
struct RechargePage: View {
    @EnvironmentObject var state: AppState
    var onBack: () -> Void

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadID = UUID()
    @State private var justToppedUp = false

    var body: some View {
        VStack(spacing: 0) {
            header
            balanceRow
            webCard
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.ground)
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
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("充值")
                    .font(DSFont.text(13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(DS.ink)

                Rectangle()
                    .fill(DS.rule)
                    .frame(width: 14, height: 1)

                Text("TOP UP")
                    .font(DSFont.label(8, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(DS.ink3)

                Spacer()

                if justToppedUp {
                    DSPill(text: "余额已更新", color: DS.ok, showsDot: false)
                } else {
                    DSPill(text: "官方充值", color: DS.ink3, showsDot: false)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            Hairline()
        }
    }

    // MARK: - 当前余额

    private var balanceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(currencySymbol)
                .font(DSFont.figure(15, weight: .medium))
                .foregroundStyle(DS.ink2)

            Text(String(format: "%.2f", state.lastBalance?.totalBalance ?? 0))
                .font(DSFont.figure(28, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(DS.ink)
                .contentTransition(.numericText())

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("支付完成后自动刷新")
                    .font(DSFont.text(8.5))
                    .foregroundStyle(DS.ink3)
                HStack(spacing: 4) {
                    Rectangle().fill(DS.ok).frame(width: 4, height: 4)
                    Text("官方支付通道")
                        .font(DSFont.text(8.5))
                        .foregroundStyle(DS.ink2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Hairline(color: DS.ruleSoft) }
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
                    .padding(10)
                    .background(DS.ground, in: Rectangle())
                    .overlay(Rectangle().strokeBorder(DS.rule, lineWidth: 1))
                    .allowsHitTesting(false)
            }

            if let errorMessage {
                VStack(spacing: 9) {
                    Text("充值页加载失败")
                        .font(DSFont.text(11.5, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text(errorMessage)
                        .font(DSFont.text(8.5))
                        .foregroundStyle(DS.ink2)
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
                .background(DS.ground)
                .overlay(Rectangle().strokeBorder(DS.rule, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Hairline(color: DS.ruleSoft) }
        .overlay(
            Rectangle()
                .strokeBorder(DS.rule, lineWidth: 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .allowsHitTesting(false)
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack(spacing: 8) {
                DSIconButton(systemName: "chevron.left", help: "返回", size: 24, action: onBack)
                Text("返回")
                    .font(DSFont.text(10, weight: .medium))
                    .foregroundStyle(DS.ink2)
                    .onTapGesture { onBack() }

                Spacer()

                Button("刷新余额") {
                    Task { await state.refreshBalance(silent: true) }
                }
                .buttonStyle(.plain)
                .font(DSFont.text(9, weight: .medium))
                .foregroundStyle(DS.ink2)

                DSIconButton(systemName: "arrow.clockwise", help: "重新加载充值页", size: 24) {
                    reloadID = UUID()
                    isLoading = true
                    errorMessage = nil
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
        }
    }
}

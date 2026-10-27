import SwiftUI
import AppKit

enum ContentPage { case main, settings, recharge, apiKeys }

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var page: ContentPage
    @State private var hasAppeared = false

    init(initialPage: ContentPage = .main) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        ZStack {
            pageContent
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
        }
        .frame(width: 380)
        .background(
            DS.background.overlay(alignment: .topTrailing) {
                RadialGradient(
                    colors: [DS.brand.opacity(0.10), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
                .allowsHitTesting(false)
            }
        )
        .animation(.easeInOut(duration: 0.20), value: page)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            guard !hasAppeared else { return }
            hasAppeared = true
            Task {
                await state.refreshBalanceIfNeeded(force: false, silent: state.lastBalance != nil)
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .main:
            MainPage(
                onOpenSettings: { go(to: .settings) },
                onOpenRecharge: { go(to: .recharge) },
                onOpenAPIKeys: { go(to: .apiKeys) }
            )
        case .settings:
            SettingsPage(onBack: { go(to: .main) })
        case .recharge:
            RechargePage(onBack: { go(to: .main) })
        case .apiKeys:
            APIKeysPage(onBack: { go(to: .main) })
        }
    }

    private func go(to destination: ContentPage) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            page = destination
        }
    }
}

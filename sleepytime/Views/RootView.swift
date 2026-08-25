import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: String = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-sleepytime-tab-trends") { return "trends" }
        if args.contains("-sleepytime-tab-settings") { return "settings" }
        return "tonight"
    }()

    var body: some View {
        ZStack {
            NightTheme.pageBackground.ignoresSafeArea()
            AuroraGlow().ignoresSafeArea()
            StarField().ignoresSafeArea()

            if model.phase == .onboarding {
                OnboardingView()
            } else {
                mainTabs
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: model.phase)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, !model.demoMode, model.phase == .ready {
                Task { await model.refresh() }
            }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-sleepytime-demo"), model.phase == .onboarding {
                await model.enterDemoMode()
            } else if model.phase == .ready, model.schedule == nil {
                await model.refresh()
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selection) {
            Tab(value: "tonight") {
                TonightView()
            } label: {
                Label("Tonight", systemImage: "moon.stars.fill")
            }
            Tab(value: "trends") {
                TrendsView()
            } label: {
                Label("Trends", systemImage: "chart.bar.fill")
            }
            Tab(value: "settings") {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(NightTheme.frost)
    }
}

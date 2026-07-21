import SwiftUI
import UIKit

@main
struct PrivateReceiptVaultApp: App {
    @StateObject private var store = ReceiptStore()
    @StateObject private var proAccess = ProAccess()
    @StateObject private var appLock = AppLock()
    @StateObject private var storeKit = StoreKitService()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppLockContainer {
                Group {
                    if hasCompletedOnboarding {
                        RootTabView()
                    } else {
                        OnboardingViewController {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
            .environmentObject(store)
            .environmentObject(proAccess)
            .environmentObject(appLock)
            .environmentObject(storeKit)
            .task {
                await storeKit.start(proAccess: proAccess)
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    appLock.prepareForForeground()
                case .inactive, .background:
                    appLock.lockIfNeeded()
                @unknown default:
                    appLock.lockIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                appLock.showPrivacyShieldIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                appLock.lockIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                appLock.prepareForForeground()
            }
        }
    }
}

struct AppLockContainer<Content: View>: View {
    @EnvironmentObject private var appLock: AppLock
    @ViewBuilder var content: Content

    var body: some View {
        content
            .fullScreenCover(isPresented: lockPresentation) {
                LockViewController()
                    .interactiveDismissDisabled(true)
            }
    }

    private var lockPresentation: Binding<Bool> {
        Binding(
            get: { appLock.isShieldVisible || !appLock.isUnlocked },
            set: { isPresented in
                if !isPresented, !appLock.isUnlocked {
                    appLock.isShieldVisible = true
                }
            }
        )
    }
}

struct RootTabView: View {
    @State private var isPaywallPresentedForTesting = false

    var body: some View {
        TabView {
            HomeViewController()
                .tabItem {
                    Label("Receipts", systemImage: "doc.text.viewfinder")
                }

            ExpenseReportsViewController()
                .tabItem {
                    Label("Packets", systemImage: "folder")
                }

            InsightsViewController()
                .tabItem {
                    Label("Insights", systemImage: "chart.pie")
                }
        }
        #if DEBUG
        .task {
            if ProcessInfo.processInfo.arguments.contains("-showPaywallForUITesting") {
                isPaywallPresentedForTesting = true
            }
        }
        .sheet(isPresented: $isPaywallPresentedForTesting) {
            PaywallViewController(
                focusPlansForTesting: ProcessInfo.processInfo.arguments.contains("-focusPaywallPlansForUITesting")
            )
        }
        #endif
    }
}

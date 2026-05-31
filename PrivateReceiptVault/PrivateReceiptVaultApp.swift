import SwiftUI

@main
struct PrivateReceiptVaultApp: App {
    @StateObject private var store = ReceiptStore()
    @StateObject private var proAccess = ProAccess()
    @StateObject private var appLock = AppLock()
    @StateObject private var storeKit = StoreKitService()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
                .environmentObject(store)
                .environmentObject(proAccess)
                .environmentObject(appLock)
                .environmentObject(storeKit)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Receipts", systemImage: "doc.text.viewfinder")
                }

            ExpenseReportsView()
                .tabItem {
                    Label("Reports", systemImage: "folder")
                }

            ReportsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.pie")
                }
        }
    }
}

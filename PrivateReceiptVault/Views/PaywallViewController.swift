import SwiftUI
import StoreKit

struct PaywallViewController: View {
    @EnvironmentObject private var proAccess: ProAccess
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    let focusPlansForTesting: Bool

    init(focusPlansForTesting: Bool = false) {
        self.focusPlansForTesting = focusPlansForTesting
    }

    private var remainingFreeReceipts: Int {
        max(ProAccess.freeReceiptLimit - store.receipts.count, 0)
    }

    var body: some View {
        NavigationStack {
            List {
                if !focusPlansForTesting {
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Theme.tint)
                                    .frame(width: 54, height: 54)
                                    .background(Theme.subscriptionSelectionBackground, in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Receipt Vault Pro")
                                        .font(.title2.bold())
                                    Text("Unlimited offline receipt storage and professional export packets.")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }

                            HStack(spacing: 10) {
                                ProStatusPill(title: "Free left", value: "\(remainingFreeReceipts)", systemImage: "doc.badge.plus")
                                ProStatusPill(title: "Saved", value: "\(store.receipts.count)", systemImage: "tray.full")
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Free") {
                        ProFeatureRow(title: "\(ProAccess.freeReceiptLimit) receipts included", subtitle: "Try scanning, OCR, search, and CSV export.", systemImage: "seal")
                        ProFeatureRow(title: "Private by default", subtitle: "No account, no bank connection, device lock, and local backup.", systemImage: "wifi.slash")
                    }

                    Section("Pro unlocks") {
                        ProComparisonView()
                        ProFeatureRow(title: "Unlimited receipts", subtitle: "Keep growing your private local archive.", systemImage: "infinity")
                        ProFeatureRow(title: "PDF export packets", subtitle: "Create polished summaries for reimbursement, taxes, or records.", systemImage: "doc.richtext")
                        ProFeatureRow(title: "ZIP with images", subtitle: "Package CSV data, PDF summaries, and original receipt images together.", systemImage: "doc.zipper")
                        ProFeatureRow(title: "Long-term archive", subtitle: "Remove the free receipt limit when your vault starts to grow.", systemImage: "archivebox")
                    }
                }

                Section("Choose your plan") {
                    if let yearlyProduct = storeKit.yearlyProduct {
                        SubscriptionPlanRow(
                            title: "Yearly",
                            period: "per year",
                            product: yearlyProduct,
                            isRecommended: true,
                            isSelected: storeKit.selectedProductID == yearlyProduct.id
                        ) {
                            storeKit.selectedProductID = yearlyProduct.id
                        }
                    }

                    if let monthlyProduct = storeKit.monthlyProduct {
                        SubscriptionPlanRow(
                            title: "Monthly",
                            period: "per month",
                            product: monthlyProduct,
                            isRecommended: false,
                            isSelected: storeKit.selectedProductID == monthlyProduct.id
                        ) {
                            storeKit.selectedProductID = monthlyProduct.id
                        }
                    }

                    if storeKit.isLoading && (storeKit.monthlyProduct == nil || storeKit.yearlyProduct == nil) {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading subscription options")
                                .foregroundStyle(Theme.secondaryText)
                        }
                    } else if storeKit.monthlyProduct == nil || storeKit.yearlyProduct == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Subscription options are unavailable. Please try again later.")
                                .foregroundStyle(Theme.secondaryText)
                            Button("Retry") {
                                Task { await storeKit.loadProducts() }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        Task {
                            await storeKit.purchaseSelectedProduct(proAccess: proAccess)
                            if proAccess.isPro { dismiss() }
                        }
                    } label: {
                        Label("Continue", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(storeKit.isLoading || storeKit.selectedProduct == nil)

                    Button("Restore Purchases") {
                        Task {
                            await storeKit.restorePurchases(proAccess: proAccess)
                            if proAccess.isPro { dismiss() }
                        }
                    }
                    .disabled(storeKit.isLoading)

                    #if DEBUG
                    if !ProcessInfo.processInfo.arguments.contains("-hideDebugControlsForUITesting") {
                        Button("Unlock Pro for testing") {
                            proAccess.unlockForTesting()
                            dismiss()
                        }
                    }
                    #endif

                    Text("Subscriptions renew automatically unless cancelled in your Apple account. Purchases are processed by Apple. Your receipts stay on this device unless you export or back them up.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)

                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: AppStoreLinks.privacyPolicyURL)
                        Link("Terms of Use", destination: AppStoreLinks.termsOfUseURL)
                    }
                    .font(.footnote)
                }
            }
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-selectMonthlyForUITesting") {
                    storeKit.selectedProductID = StoreKitService.monthlyProductID
                }
                #endif
                await storeKit.start(proAccess: proAccess)
            }
            .alert("Purchase", isPresented: Binding(
                get: { storeKit.errorMessage != nil },
                set: { if !$0 { storeKit.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(storeKit.errorMessage ?? "")
            }
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct SubscriptionPlanRow: View {
    let title: LocalizedStringKey
    let period: LocalizedStringKey
    let product: Product
    let isRecommended: Bool
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(Theme.tint)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.subscriptionBadgeBackground, in: Capsule())
                        }
                    }
                    HStack(spacing: 5) {
                        Text(product.displayPrice)
                            .font(.title3.bold())
                        Text(period)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Theme.subscriptionSelectionBackground : Theme.secondarySurface)
        .accessibilityValue(isSelected ? String(localized: "Selected") : "")
    }
}

private struct ProComparisonView: View {
    private let rows: [(LocalizedStringKey, LocalizedStringKey, LocalizedStringKey)] = [
        ("Receipts", "30 forever", "Unlimited"),
        ("Exports", "CSV", "PDF + ZIP + images"),
        ("Packets", "Create + view", "Professional export"),
        ("Backup", "Local file", "Local file"),
        ("Privacy", "Lock included", "Lock included")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feature")
                Spacer()
                Text("Free")
                    .frame(width: 82, alignment: .trailing)
                Text("Pro")
                    .frame(width: 112, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
            .padding(.bottom, 7)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(row.1)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 82, alignment: .trailing)
                    Text(row.2)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.titleLevel1)
                        .frame(width: 112, alignment: .trailing)
                }
                .padding(.vertical, 7)
                Divider()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProStatusPill: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.secondarySurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProFeatureRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.tint)
                .frame(width: 30, height: 30)
                .background(Theme.subscriptionSelectionBackground, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }
}

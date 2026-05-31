import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var proAccess: ProAccess
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss

    private var remainingFreeReceipts: Int {
        max(ProAccess.freeReceiptLimit - store.receipts.count, 0)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.tint)
                                .frame(width: 54, height: 54)
                                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Receipt Vault Pro")
                                    .font(.title2.bold())
                                Text("Unlimited offline receipt storage, protected exports, and professional reports.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                    ProFeatureRow(title: "Offline by default", subtitle: "No account, no bank connection, no server upload.", systemImage: "wifi.slash")
                }

                Section("Pro unlocks") {
                    ProComparisonView()
                    ProFeatureRow(title: "Unlimited receipts", subtitle: "Keep growing your private local archive.", systemImage: "infinity")
                    ProFeatureRow(title: "Professional reports", subtitle: "PDF, ZIP, images, summaries, and expense packets.", systemImage: "doc.richtext")
                    ProFeatureRow(title: "Insights charts", subtitle: "Trends, categories, tax totals, and comparison metrics.", systemImage: "chart.pie")
                    ProFeatureRow(title: "Encrypted backups", subtitle: "Reinstall anytime and restore from Files or iCloud Drive.", systemImage: "externaldrive.badge.checkmark")
                    ProFeatureRow(title: "Duplicate detection", subtitle: "Reduce accidental double entry before saving.", systemImage: "doc.on.doc")
                    ProFeatureRow(title: "Privacy lock", subtitle: "Protect the vault with device authentication.", systemImage: "faceid")
                }

                Section {
                    Button {
                        Task {
                            await storeKit.purchase(proAccess: proAccess)
                            if proAccess.isPro { dismiss() }
                        }
                    } label: {
                        Label(storeKit.product?.displayPrice ?? "Buy Pro", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(storeKit.isLoading)

                    Button("Restore Purchases") {
                        Task {
                            await storeKit.restorePurchases(proAccess: proAccess)
                            if proAccess.isPro { dismiss() }
                        }
                    }
                    .disabled(storeKit.isLoading)

                    #if DEBUG
                    Button("Unlock Pro for testing") {
                        proAccess.unlockForTesting()
                        dismiss()
                    }
                    #endif

                    Text("One-time Pro unlock. Purchases are processed by Apple. Your receipts stay on this device unless you export or back them up.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await storeKit.loadProducts()
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

private struct ProComparisonView: View {
    private let rows: [(LocalizedStringKey, LocalizedStringKey, LocalizedStringKey)] = [
        ("Receipts", "30 forever", "Unlimited"),
        ("Exports", "CSV", "PDF + ZIP + images"),
        ("Reports", "Basic", "Charts + summaries"),
        ("Backup", "Manual file", "Password protected"),
        ("Privacy", "Local storage", "Lock + encrypted backup")
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
            .foregroundStyle(.secondary)
            .padding(.bottom, 7)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(row.1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 82, alignment: .trailing)
                    Text(row.2)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
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
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProFeatureRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

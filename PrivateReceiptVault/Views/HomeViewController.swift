import SwiftUI

struct HomeViewController: View {
    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var proAccess: ProAccess

    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var showingExportOptions = false
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var receiptListRoute: ReceiptListRoute?

    private var recentReceipts: [Receipt] {
        Array(store.receipts.sorted { $0.date > $1.date }.prefix(5))
    }
    private var unclassifiedCount: Int {
        store.receipts.filter { $0.category == .other }.count
    }
    private var reimbursableReceiptCount: Int {
        store.receipts.filter { $0.reimbursementState == .reimbursable }.count
    }
    private var taxRecordCount: Int {
        store.receipts.filter { $0.tax != nil }.count
    }
    private var autoClassifiedPercent: Int {
        guard !store.receipts.isEmpty else { return 0 }
        let classifiedCount = store.receipts.count - unclassifiedCount
        return Int((Double(classifiedCount) / Double(store.receipts.count) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AllReceiptsViewController()
                    } label: {
                        SearchEntryRow()
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        SummaryView(
                            receiptCount: store.receipts.count,
                            reimbursableReceiptCount: reimbursableReceiptCount,
                            taxRecordCount: taxRecordCount,
                            autoClassifiedPercent: autoClassifiedPercent,
                            unclassifiedCount: unclassifiedCount,
                            scanAction: {
                                if proAccess.canAddReceipt(currentCount: store.receipts.count) {
                                    showingScanner = true
                                } else {
                                    showingPaywall = true
                                }
                            },
                            needsCategoryAction: {
                                receiptListRoute = ReceiptListRoute(category: .other)
                            },
                            allReceiptsAction: {
                                receiptListRoute = ReceiptListRoute(category: nil)
                            },
                            reimbursableAction: {
                                receiptListRoute = ReceiptListRoute(category: nil, reimbursementFilter: .reimbursable)
                            },
                            taxRecordsAction: {
                                receiptListRoute = ReceiptListRoute(category: nil, taxOnly: true)
                            }
                        )
                        TrustBadgesView()
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section("最近收据") {
                    if store.receipts.isEmpty {
                        ContentUnavailableView(
                            "No receipts yet",
                            systemImage: "doc.text.viewfinder",
                            description: Text("Scan or import a receipt to extract merchant, date, tax, and total on device.")
                        )
                    } else {
                        ForEach(recentReceipts) { receipt in
                            NavigationLink {
                                DetailViewController(receipt: receipt)
                            } label: {
                                ReceiptRow(receipt: receipt)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { recentReceipts[$0] }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Receipt Vault")
            .navigationDestination(item: $receiptListRoute) { route in
                AllReceiptsViewController(
                    initialCategory: route.category,
                    reimbursementFilter: route.reimbursementFilter,
                    taxOnly: route.taxOnly
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "lock.shield")
                    }
                    .accessibilityLabel("Privacy")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingExportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(store.receipts.isEmpty)
                    .accessibilityLabel("Export")

                    Button {
                        if proAccess.canAddReceipt(currentCount: store.receipts.count) {
                            showingScanner = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add receipt")
                }
            }
            .sheet(isPresented: $showingScanner) {
                AddGuideViewController()
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsViewController()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewController()
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView { options in
                    export(options)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .alert("Export failed", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private func export(_ options: ExportOptions) {
        guard options.kind == .csv || proAccess.isPro else {
            showingPaywall = true
            return
        }

        let receiptsToExport = options.filteredReceipts(from: store.receipts)
        guard !receiptsToExport.isEmpty else {
            exportError = String(localized: "No receipts match these export filters.")
            return
        }

        do {
            switch options.kind {
            case .csv:
                shareItem = ShareItem(url: try store.exportCSV(receipts: receiptsToExport))
            case .pdf:
                shareItem = ShareItem(url: try store.exportPDF(receipts: receiptsToExport))
            case .zip:
                shareItem = ShareItem(url: try store.exportZIP(receipts: receiptsToExport))
            }
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ReceiptListRoute: Identifiable, Hashable {
    let id = UUID()
    var category: ReceiptCategory?
    var reimbursementFilter: ReceiptReimbursementFilter = .all
    var taxOnly = false
}

private struct SearchEntryRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text("搜索全部收据")
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.tint)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LockViewController: View {
    @EnvironmentObject private var appLock: AppLock

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 58))
                .foregroundStyle(.tint)
            Text("Receipt Vault Locked")
                .font(.title2.bold())
            Text("Unlock to view private receipts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                appLock.authenticate()
            } label: {
                Label("Unlock with \(appLock.lockName)", systemImage: "faceid")
                    .frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

private struct SummaryView: View {
    let receiptCount: Int
    let reimbursableReceiptCount: Int
    let taxRecordCount: Int
    let autoClassifiedPercent: Int
    let unclassifiedCount: Int
    let scanAction: () -> Void
    let needsCategoryAction: () -> Void
    let allReceiptsAction: () -> Void
    let reimbursableAction: () -> Void
    let taxRecordsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if receiptCount == 0 {
                FirstReceiptChecklist()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatPill(title: "收据", value: localizedReceiptCount(receiptCount), systemImage: "doc.text", action: allReceiptsAction)
                    StatPill(title: "可报销", value: localizedReceiptCount(reimbursableReceiptCount), systemImage: "briefcase", action: reimbursableAction)
                    StatPill(title: "税务记录", value: localizedReceiptCount(taxRecordCount), systemImage: "percent", action: taxRecordsAction)
                }

                if unclassifiedCount > 0 {
                    HStack(spacing: 10) {
                        ReviewChip(title: String(format: String(localized: "NeedsCategoryCountFormat"), unclassifiedCount), systemImage: "tag", color: Theme.appGreen, action: needsCategoryAction)
                    }
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(receiptCount == 0 ? "开始整理你的第一张收据" : "收据整理进度")
                    .font(.title3.bold())
                Text(receiptCount == 0 ? "识别后可核对商户、金额、日期和分类" : unclassifiedCount > 0 ? "还有 \(unclassifiedCount) 张待分类" : "分类完成 \(autoClassifiedPercent)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: scanAction) {
                VStack(spacing: 2) {
                    Label("添加收据", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                    Text("识别后可核对")
                        .font(.caption2.weight(.medium))
                        .opacity(0.86)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minWidth: 96, minHeight: 48)
                .background(.tint, in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("添加收据，识别后可核对")
            .buttonStyle(.plain)
        }
    }

    private func localizedReceiptCount(_ count: Int) -> String {
        String(format: String(localized: "ReceiptCountFormat"), count)
    }
}

private struct FirstReceiptChecklist: View {
    private let fields = ["商户", "金额", "日期", "分类"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("扫描后识别，可在保存前核对：")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(fields, id: \.self) { field in
                    Label(field, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    let systemImage: String
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ReviewChip: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: receipt.category.systemImage)
                .foregroundStyle(receipt.category.color)
                .frame(width: 34, height: 34)
                .background(receipt.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.merchant)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(receipt.date.formatted(date: .abbreviated, time: .omitted)) · \(receipt.category.localizedName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if receipt.reimbursementState != .notReimbursable {
                    Text(receipt.reimbursementState.localizedName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(receipt.reimbursementState == .reimbursed ? .green : .orange)
                }
            }

            Spacer()

            Text(receipt.total.formatted(.currency(code: receipt.currencyCode)))
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

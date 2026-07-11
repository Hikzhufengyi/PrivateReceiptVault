import SwiftUI

struct ContentView: View {
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
                        ReceiptsListView()
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
                                ReceiptDetailView(receipt: receipt)
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
                ReceiptsListView(initialCategory: route.category)
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
                ScanView()
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
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
}

private struct ReceiptsListView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var searchText = ""
    @State private var selectedCategory: ReceiptCategory?
    @State private var dateFilter: ReceiptDateFilter = .all
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEndDate = Date()
    @State private var reimbursementFilter: ReceiptReimbursementFilter = .all

    init(initialCategory: ReceiptCategory? = nil) {
        _selectedCategory = State(initialValue: initialCategory)
    }

    private var filteredReceipts: [Receipt] {
        store.filteredReceipts(query: searchText, category: selectedCategory, dateFilter: dateFilter == .custom ? .all : dateFilter, amountFilter: .all, reimbursementFilter: reimbursementFilter)
            .filter(matchesCustomDateRange)
    }

    private var filteredTotals: [(currencyCode: String, total: Decimal)] {
        let groupedTotals = Dictionary(grouping: filteredReceipts, by: \.currencyCode)
            .mapValues { receipts in
                receipts.reduce(Decimal.zero) { partialResult, receipt in
                    partialResult + receipt.total
                }
            }
        return groupedTotals
            .map { (currencyCode: $0.key, total: $0.value) }
            .sorted { $0.currencyCode < $1.currencyCode }
    }

    var body: some View {
        List {
            Section {
                FilterBar(
                    category: $selectedCategory,
                    dateFilter: $dateFilter,
                    customStartDate: $customStartDate,
                    customEndDate: $customEndDate,
                    reimbursementFilter: $reimbursementFilter
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            Section {
                if store.receipts.isEmpty {
                    ContentUnavailableView(
                        "No receipts yet",
                        systemImage: "doc.text.viewfinder",
                        description: Text("Scan or import a receipt to extract merchant, date, tax, and total on device.")
                    )
                } else if filteredReceipts.isEmpty {
                    ContentUnavailableView.search
                } else {
                    ForEach(filteredReceipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(receipt: receipt)
                        } label: {
                            ReceiptRow(receipt: receipt)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if receipt.reimbursementState == .reimbursable {
                                Button {
                                    markReceiptAsReimbursed(receipt)
                                } label: {
                                    Label("已报销", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { filteredReceipts[$0] }.forEach(store.delete)
                    }
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text("所有收据")
                    Spacer()
                    Text(receiptStatsSummary)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .navigationTitle("所有收据")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索商户、项目、备注")
    }

    private func markReceiptAsReimbursed(_ receipt: Receipt) {
        var updated = receipt
        updated.reimbursementStatus = .reimbursed
        store.update(updated)
    }

    private var receiptStatsSummary: String {
        let totalsText: String
        if filteredTotals.isEmpty {
            totalsText = Decimal.zero.formatted(.currency(code: CurrencyOption.defaultCode))
        } else if filteredTotals.count == 1, let total = filteredTotals.first {
            totalsText = total.total.formatted(.currency(code: total.currencyCode))
        } else {
            totalsText = filteredTotals
                .map { "\($0.currencyCode) \($0.total.formatted(.currency(code: $0.currencyCode)))" }
                .joined(separator: " / ")
        }
        return "\(filteredReceipts.count) 张 · \(totalsText)"
    }

    private func matchesCustomDateRange(_ receipt: Receipt) -> Bool {
        guard dateFilter == .custom else { return true }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
        let endStart = calendar.startOfDay(for: max(customStartDate, customEndDate))
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? endStart
        return receipt.date >= start && receipt.date <= end
    }
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

private struct ReceiptListStatsView: View {
    let receiptCount: Int
    let totals: [(currencyCode: String, total: Decimal)]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Label("\(receiptCount) 张", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text("总金额")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if totals.isEmpty {
                    Text(Decimal.zero.formatted(.currency(code: CurrencyOption.defaultCode)))
                        .font(.headline)
                        .monospacedDigit()
                } else if totals.count == 1, let total = totals.first {
                    Text(total.total.formatted(.currency(code: total.currencyCode)))
                        .font(.headline)
                        .monospacedDigit()
                } else {
                    ForEach(totals, id: \.currencyCode) { total in
                        Text(total.total.formatted(.currency(code: total.currencyCode)))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LockScreenView: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if receiptCount == 0 {
                FirstReceiptChecklist()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatPill(title: "收据", value: "\(receiptCount) 张", systemImage: "doc.text")
                    StatPill(title: "可报销", value: "\(reimbursableReceiptCount) 张", systemImage: "briefcase")
                    StatPill(title: "税务记录", value: "\(taxRecordCount) 张", systemImage: "percent")
                }

                if unclassifiedCount > 0 {
                    HStack(spacing: 10) {
                        ReviewChip(title: "\(unclassifiedCount) 张待分类", systemImage: "tag", color: .green, action: needsCategoryAction)
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
                Text(receiptCount == 0 ? "AI 等待整理你的第一张收据" : "AI 已完成整理")
                    .font(.title3.bold())
                Text(receiptCount == 0 ? "扫描后自动识别商户、金额、日期和分类" : "分类完成 \(autoClassifiedPercent)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: scanAction) {
                VStack(spacing: 2) {
                    Label("添加收据", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                    Text("AI 自动识别")
                        .font(.caption2.weight(.medium))
                        .opacity(0.86)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minWidth: 96, minHeight: 48)
                .background(.tint, in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("添加收据，AI 自动识别")
            .buttonStyle(.plain)
        }
    }
}

private struct FirstReceiptChecklist: View {
    private let fields = ["商户", "金额", "日期", "分类"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("扫描后自动识别：")
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

private struct ReceiptRow: View {
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

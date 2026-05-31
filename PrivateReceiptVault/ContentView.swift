import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var proAccess: ProAccess
    @EnvironmentObject private var appLock: AppLock
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var showingExportOptions = false
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var searchText = ""
    @State private var selectedCategory: ReceiptCategory?
    @State private var dateFilter: ReceiptDateFilter = .all

    private var filteredReceipts: [Receipt] {
        store.filteredReceipts(query: searchText, category: selectedCategory, dateFilter: dateFilter)
    }
    private var currencyCode: String {
        store.receipts.first?.currencyCode ?? CurrencyOption.defaultCode
    }
    private var monthlyReceipts: [Receipt] {
        store.receipts.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }
    private var monthlyTotal: Decimal {
        monthlyReceipts.reduce(Decimal.zero) { $0 + $1.total }
    }
    private var unclassifiedCount: Int {
        store.receipts.filter { $0.category == .other }.count
    }
    private var incompleteCount: Int {
        store.receipts.filter { receipt in
            receipt.merchant == "Unknown merchant" ||
            receipt.tax == nil ||
            receipt.subtotal == nil ||
            receipt.paymentMethod.isEmpty ||
            receipt.imageFileName == nil
        }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        SummaryView(
                            monthlyTotal: monthlyTotal,
                            currencyCode: currencyCode,
                            receiptCount: store.receipts.count,
                            monthlyReceiptCount: monthlyReceipts.count,
                            unclassifiedCount: unclassifiedCount,
                            incompleteCount: incompleteCount
                        ) {
                            if proAccess.canAddReceipt(currentCount: store.receipts.count) {
                                showingScanner = true
                            } else {
                                showingPaywall = true
                            }
                        }
                        TrustBadgesView()
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    FilterBar(category: $selectedCategory, dateFilter: $dateFilter)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Section("Receipts") {
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
                        }
                        .onDelete { offsets in
                            offsets.map { filteredReceipts[$0] }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Receipt Vault")
            .searchable(text: $searchText, prompt: "Search merchant, project, notes")
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
            .overlay {
                if appLock.isShieldVisible || !appLock.isUnlocked {
                    LockScreenView()
                }
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

private struct LockScreenView: View {
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
    let monthlyTotal: Decimal
    let currencyCode: String
    let receiptCount: Int
    let monthlyReceiptCount: Int
    let unclassifiedCount: Int
    let incompleteCount: Int
    let scanAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(monthlyTotal.formatted(.currency(code: currencyCode)))
                        .font(.title.bold())
                        .monospacedDigit()
                }
                Spacer()
                Button(action: scanAction) {
                    Image(systemName: "doc.viewfinder")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Scan receipt")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatPill(title: "Receipts", value: "\(receiptCount)", systemImage: "doc.text")
                StatPill(title: "This month", value: "\(monthlyReceiptCount)", systemImage: "calendar")
                StatPill(title: "Needs category", value: "\(unclassifiedCount)", systemImage: "tag")
                StatPill(title: "Needs review", value: "\(incompleteCount)", systemImage: "exclamationmark.magnifyingglass")
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
            }

            Spacer()

            Text(receipt.total.formatted(.currency(code: receipt.currencyCode)))
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

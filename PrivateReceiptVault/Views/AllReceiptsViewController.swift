import SwiftUI

struct AllReceiptsViewController: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var searchText = ""
    @State private var selectedCategory: ReceiptCategory?
    @State private var dateFilter: ReceiptDateFilter = .all
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEndDate = Date()
    @State private var reimbursementFilter: ReceiptReimbursementFilter
    private let taxOnly: Bool

    init(initialCategory: ReceiptCategory? = nil, reimbursementFilter: ReceiptReimbursementFilter = .all, taxOnly: Bool = false) {
        _selectedCategory = State(initialValue: initialCategory)
        _reimbursementFilter = State(initialValue: reimbursementFilter)
        self.taxOnly = taxOnly
    }

    private var filteredReceipts: [Receipt] {
        store.filteredReceipts(query: searchText, category: selectedCategory, dateFilter: dateFilter == .custom ? .all : dateFilter, amountFilter: .all, reimbursementFilter: reimbursementFilter)
            .filter(matchesCustomDateRange)
            .filter { receipt in
                !taxOnly || receipt.tax != nil
            }
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
        VStack(spacing: 0) {
            ReceiptListSearchBar(searchText: $searchText)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(.regularMaterial)

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
                                DetailViewController(receipt: receipt)
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
                                    .tint(Theme.appGreen)
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
                            .foregroundStyle(Theme.titleLevel1)
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle("所有收据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
        return String(format: String(localized: "ReceiptStatsFormat"), filteredReceipts.count, totalsText)
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

private struct ReceiptListSearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.titleLevel2)
            TextField(String(localized: "Search merchant, project, notes"), text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.titleLevel2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.searchBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

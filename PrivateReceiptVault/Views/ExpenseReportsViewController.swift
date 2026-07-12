import SwiftUI

struct ExpenseReportsViewController: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                if store.expenseReports.isEmpty {
                    ContentUnavailableView(
                        "No packets yet",
                        systemImage: "folder.badge.plus",
                        description: Text("Create a packet for reimbursement, taxes, warranties, or records.")
                    )
                } else {
                    ForEach(store.expenseReports) { report in
                        NavigationLink {
                            ExpenseReportDetailView(report: report)
                        } label: {
                            ExpenseReportRow(report: report, receipts: store.receipts(for: report))
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.expenseReports[$0] }.forEach(store.deleteExpenseReport)
                    }
                }
            }
            .navigationTitle("Packets")
            .toolbar {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingEditor) {
                ExpenseReportEditorView()
            }
        }
    }
}

private struct ExpenseReportRow: View {
    let report: ExpenseReport
    let receipts: [Receipt]

    private var total: Decimal {
        receipts.reduce(Decimal.zero) { $0 + $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.title)
                    .font(.headline)
                Spacer()
                Text(report.status.localizedName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("\(report.startDate.formatted(date: .abbreviated, time: .omitted)) - \(report.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(receipts.count) receipts · \(total.formatted(.currency(code: receipts.first?.currencyCode ?? CurrencyOption.defaultCode)))")
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct ExpenseReportEditorView: View {
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ExpenseReportDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section("Packet") {
                    TextField("Title", text: $draft.title)
                    TextField("Company", text: $draft.companyName)
                    TextField("Claimant", text: $draft.claimantName)
                    TextField("Department", text: $draft.department)
                    DatePicker("Start date", selection: $draft.startDate, displayedComponents: .date)
                    DatePicker("End date", selection: $draft.endDate, displayedComponents: .date)
                    Picker("Status", selection: $draft.status) {
                        ForEach(ExpenseReportStatus.allCases) { status in
                            Text(status.localizedName).tag(status)
                        }
                    }
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Receipts") {
                    ForEach(filteredReceipts) { receipt in
                        Toggle(isOn: receiptBinding(receipt.id)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(receipt.merchant)
                                Text("\(receipt.date.formatted(date: .abbreviated, time: .omitted)) · \(receipt.total.formatted(.currency(code: receipt.currencyCode)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Packet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addExpenseReport(draft)
                        dismiss()
                    }
                    .disabled(draft.receiptIDs.isEmpty)
                }
            }
            .onAppear {
                draft.receiptIDs = filteredReceipts.map(\.id)
            }
        }
    }

    private var filteredReceipts: [Receipt] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: draft.startDate)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: draft.endDate) ?? draft.endDate
        return store.receipts.filter { $0.date >= start && $0.date <= end }
    }

    private func receiptBinding(_ id: UUID) -> Binding<Bool> {
        Binding {
            draft.receiptIDs.contains(id)
        } set: { isSelected in
            if isSelected {
                if !draft.receiptIDs.contains(id) { draft.receiptIDs.append(id) }
            } else {
                draft.receiptIDs.removeAll { $0 == id }
            }
        }
    }
}

struct ExpenseReportDetailView: View {
    @EnvironmentObject private var store: ReceiptStore
    let report: ExpenseReport

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Status", value: report.status.localizedName)
                if !report.companyName.isEmpty {
                    LabeledContent("Company", value: report.companyName)
                }
                if !report.claimantName.isEmpty {
                    LabeledContent("Claimant", value: report.claimantName)
                }
                if !report.department.isEmpty {
                    LabeledContent("Department", value: report.department)
                }
                LabeledContent("Receipts", value: "\(receipts.count)")
                LabeledContent("Total", value: total.formatted(.currency(code: receipts.first?.currencyCode ?? CurrencyOption.defaultCode)))
            }

            Section("Receipts") {
                ForEach(receipts) { receipt in
                    NavigationLink {
                        DetailViewController(receipt: receipt)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(receipt.merchant)
                            Text(receipt.total.formatted(.currency(code: receipt.currencyCode)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(report.title)
    }

    private var receipts: [Receipt] {
        store.receipts(for: report)
    }

    private var total: Decimal {
        receipts.reduce(Decimal.zero) { $0 + $1.total }
    }
}

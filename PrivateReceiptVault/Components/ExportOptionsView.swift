import SwiftUI

enum ExportKind: String, CaseIterable, Identifiable {
    case csv
    case pdf
    case zip

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .csv:
            return "CSV"
        case .pdf:
            return "PDF"
        case .zip:
            return "ZIP"
        }
    }

    var systemImage: String {
        switch self {
        case .csv:
            return "tablecells"
        case .pdf:
            return "doc.richtext"
        case .zip:
            return "doc.zipper"
        }
    }
}

enum ExportDateRange: String, CaseIterable, Identifiable {
    case all
    case thisMonth
    case thisYear
    case custom

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all:
            return "All dates"
        case .thisMonth:
            return "This month"
        case .thisYear:
            return "This year"
        case .custom:
            return "Custom range"
        }
    }
}

struct ExportOptions {
    var kind: ExportKind = .csv
    var dateRange: ExportDateRange = .all
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var endDate: Date = .now
    var category: ReceiptCategory?

    func filteredReceipts(from receipts: [Receipt]) -> [Receipt] {
        receipts
            .filter(matchesDate)
            .filter { receipt in
                category == nil || receipt.category == category
            }
            .sorted { $0.date > $1.date }
    }

    private func matchesDate(_ receipt: Receipt) -> Bool {
        let calendar = Calendar.current
        switch dateRange {
        case .all:
            return true
        case .thisMonth:
            return calendar.isDate(receipt.date, equalTo: .now, toGranularity: .month)
        case .thisYear:
            return calendar.isDate(receipt.date, equalTo: .now, toGranularity: .year)
        case .custom:
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            return receipt.date >= start && receipt.date <= end
        }
    }
}

struct ExportOptionsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var options = ExportOptions()

    let onExport: (ExportOptions) -> Void

    private var previewReceipts: [Receipt] {
        options.filteredReceipts(from: store.receipts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $options.kind) {
                        ForEach(ExportKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Date range") {
                    Picker("Date range", selection: $options.dateRange) {
                        ForEach(ExportDateRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }

                    if options.dateRange == .custom {
                        DatePicker("Start date", selection: $options.startDate, displayedComponents: .date)
                        DatePicker("End date", selection: $options.endDate, displayedComponents: .date)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $options.category) {
                        Text("All").tag(nil as ReceiptCategory?)
                        ForEach(ReceiptCategory.allCases) { category in
                            Text(category.localizedName).tag(category as ReceiptCategory?)
                        }
                    }
                }

                Section {
                    HStack {
                        Label("Receipts", systemImage: "doc.text")
                        Spacer()
                        Text("\(previewReceipts.count)")
                            .foregroundStyle(previewReceipts.isEmpty ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        dismiss()
                        onExport(options)
                    }
                    .disabled(previewReceipts.isEmpty)
                }
            }
            .onChange(of: options.startDate) { _, newValue in
                if newValue > options.endDate {
                    options.endDate = newValue
                }
            }
            .onChange(of: options.endDate) { _, newValue in
                if newValue < options.startDate {
                    options.startDate = newValue
                }
            }
        }
    }
}

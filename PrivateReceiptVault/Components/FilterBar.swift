import SwiftUI

enum ReceiptDateFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case thisMonth = "Month"
    case thisYear = "Year"
    case custom = "自定义"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
}

enum ReceiptAmountFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case under50 = "< 50"
    case from50To200 = "50-200"
    case over200 = "200+"

    var id: String { rawValue }
}

enum ReceiptReimbursementFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case reimbursable = "可报销"
    case reimbursed = "已报销"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
}

struct FilterBar: View {
    @Binding var category: ReceiptCategory?
    @Binding var dateFilter: ReceiptDateFilter
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    @Binding var reimbursementFilter: ReceiptReimbursementFilter
    @State private var showingCustomDateSheet = false
    @State private var draftStartDate = Date()
    @State private var draftEndDate = Date()

    var body: some View {
        VStack(spacing: 10) {
            Picker("Date", selection: $dateFilter) {
                ForEach(ReceiptDateFilter.allCases) { filter in
                    Text(filter.localizedName).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if dateFilter == .custom {
                Button {
                    draftStartDate = customStartDate
                    draftEndDate = customEndDate
                    showingCustomDateSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.tint)
                        Text(customDateRangeText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Picker("Reimbursement", selection: $reimbursementFilter) {
                ForEach(ReceiptReimbursementFilter.allCases) { filter in
                    Text(filter.localizedName).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "All", isSelected: category == nil) {
                        category = nil
                    }
                    ForEach(ReceiptCategory.allCases) { item in
                        CategoryChip(title: item.localizedName, isSelected: category == item) {
                            category = item
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .sheet(isPresented: $showingCustomDateSheet) {
            NavigationStack {
                Form {
                    Section("自定义日期") {
                        DatePicker("开始日期", selection: $draftStartDate, displayedComponents: .date)
                        DatePicker("结束日期", selection: $draftEndDate, displayedComponents: .date)
                    }
                }
                .navigationTitle("选择日期范围")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            showingCustomDateSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确认") {
                            customStartDate = draftStartDate
                            customEndDate = draftEndDate
                            showingCustomDateSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var customDateRangeText: String {
        let start = min(customStartDate, customEndDate).formatted(date: .abbreviated, time: .omitted)
        let end = max(customStartDate, customEndDate).formatted(date: .abbreviated, time: .omitted)
        return "\(start) - \(end)"
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

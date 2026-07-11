import Charts
import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var range: ReportRange = .thisMonth
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEndDate = Date()

    private var calendar: Calendar { .current }
    private var filteredReceipts: [Receipt] {
        store.receipts.filter { receipt in
            switch range {
            case .all:
                return true
            case .thisMonth:
                return calendar.isDate(receipt.date, equalTo: .now, toGranularity: .month)
            case .thisYear:
                return calendar.isDate(receipt.date, equalTo: .now, toGranularity: .year)
            case .custom:
                let start = calendar.startOfDay(for: customStartDate)
                let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
                return receipt.date >= start && receipt.date <= end
            }
        }
    }
    private var totalAmount: Decimal { total(filteredReceipts) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ReportRangePicker(range: $range)

                    if range == .custom {
                        DatePicker("Start", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("End", selection: $customEndDate, displayedComponents: .date)
                    }
                }

                Section("Overview") {
                    ReportMetricRow(title: range.title, value: totalAmount, systemImage: range.systemImage, currencyCode: defaultCurrency)
                    ReportMetricRow(title: "Tax total", value: taxTotal(filteredReceipts), systemImage: "percent")
                    ReportMetricRow(title: "Receipts", valueText: "\(filteredReceipts.count)", systemImage: "doc.text")
                    ReportMetricRow(title: "Average receipt", value: averageReceiptAmount, systemImage: "divide", currencyCode: defaultCurrency)
                    ReportMetricRow(title: "Largest receipt", value: largestReceiptAmount, systemImage: "arrow.up.forward", currencyCode: defaultCurrency)
                    ReportMetricRow(title: "Top category", valueText: topCategoryLabel, systemImage: "chart.pie")
                    ReportMetricRow(title: comparisonTitle, valueText: comparisonLabel, systemImage: comparisonIcon)
                }

                Section("Spending Trend") {
                    SpendingTrendChart(rows: trendRows, currencyCode: defaultCurrency)
                }

                Section("Category Chart") {
                    CategoryPieChart(rows: categoryRows, total: totalAmount, currencyCode: defaultCurrency)
                }

                Section("Category Breakdown") {
                    ForEach(categoryRows, id: \.category) { row in
                        HStack {
                            Label {
                                Text(row.category.localizedName)
                            } icon: {
                                Image(systemName: row.category.systemImage)
                                    .foregroundStyle(row.category.color)
                            }
                            Spacer()
                            Text(row.total.formatted(.currency(code: defaultCurrency)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Top Merchants") {
                    ForEach(topMerchants, id: \.name) { merchant in
                        HStack {
                            Text(merchant.name)
                            Spacer()
                            Text(merchant.total.formatted(.currency(code: defaultCurrency)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .onChange(of: customStartDate) { _, newValue in
                if newValue > customEndDate {
                    customEndDate = newValue
                }
            }
            .onChange(of: customEndDate) { _, newValue in
                if newValue < customStartDate {
                    customStartDate = newValue
                }
            }
        }
    }

    private var defaultCurrency: String {
        store.receipts.first?.currencyCode ?? CurrencyOption.defaultCode
    }

    private var categoryRows: [(category: ReceiptCategory, total: Decimal)] {
        ReceiptCategory.allCases.compactMap { category in
            let value = total(filteredReceipts.filter { $0.category == category })
            return value > 0 ? (category, value) : nil
        }
    }

    private var topMerchants: [(name: String, total: Decimal)] {
        Dictionary(grouping: filteredReceipts, by: \.merchant)
            .map { (name: $0.key, total: total($0.value)) }
            .sorted { $0.total > $1.total }
            .prefix(8)
            .map { $0 }
    }

    private var previousReceipts: [Receipt] {
        switch range {
        case .thisMonth:
            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: .now) else { return [] }
            return store.receipts.filter { calendar.isDate($0.date, equalTo: previousMonth, toGranularity: .month) }
        case .thisYear:
            guard let previousYear = calendar.date(byAdding: .year, value: -1, to: .now) else { return [] }
            return store.receipts.filter { calendar.isDate($0.date, equalTo: previousYear, toGranularity: .year) }
        case .custom:
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
            guard let days = calendar.dateComponents([.day], from: start, to: end).day,
                  let previousEnd = calendar.date(byAdding: .day, value: -1, to: start),
                  let previousStart = calendar.date(byAdding: .day, value: -(days + 1), to: start) else { return [] }
            return store.receipts.filter { $0.date >= previousStart && $0.date <= previousEnd }
        case .all:
            return []
        }
    }

    private var averageReceiptAmount: Decimal {
        guard !filteredReceipts.isEmpty else { return 0 }
        return totalAmount / Decimal(filteredReceipts.count)
    }

    private var largestReceiptAmount: Decimal {
        filteredReceipts.map(\.total).max() ?? 0
    }

    private var topCategoryLabel: String {
        guard let top = categoryRows.max(by: { $0.total < $1.total }) else { return String(localized: "None") }
        return top.category.localizedName
    }

    private var comparisonTitle: LocalizedStringKey {
        switch range {
        case .thisMonth: "vs last month"
        case .thisYear: "vs last year"
        case .custom: "vs previous period"
        case .all: "Comparison"
        }
    }

    private var comparisonLabel: String {
        guard range != .all else { return String(localized: "Choose a period") }
        let previousTotal = total(previousReceipts)
        guard previousTotal > 0 else { return String(localized: "No previous data") }
        let change = ((totalAmount - previousTotal) / previousTotal) * 100
        let number = NSDecimalNumber(decimal: change).doubleValue
        return number.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())) + "%"
    }

    private var comparisonIcon: String {
        let previousTotal = total(previousReceipts)
        if totalAmount >= previousTotal {
            return "arrow.up.right"
        }
        return "arrow.down.right"
    }

    private var trendRows: [SpendingTrendRow] {
        let components: Set<Calendar.Component> = range == .thisYear ? [.year, .month] : [.year, .month, .day]
        let grouped = Dictionary(grouping: filteredReceipts) { receipt in
            let dateComponents = calendar.dateComponents(components, from: receipt.date)
            return calendar.date(from: dateComponents) ?? calendar.startOfDay(for: receipt.date)
        }

        return grouped
            .map { SpendingTrendRow(date: $0.key, total: doubleValue(total($0.value))) }
            .sorted { $0.date < $1.date }
    }

    private func total(_ receipts: [Receipt]) -> Decimal {
        receipts.reduce(Decimal.zero) { $0 + $1.total }
    }

    private func taxTotal(_ receipts: [Receipt]) -> Decimal {
        receipts.reduce(Decimal.zero) { $0 + ($1.tax ?? 0) }
    }

    private func doubleValue(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}

private struct SpendingTrendRow: Identifiable {
    let date: Date
    let total: Double

    var id: Date { date }
}

private struct SpendingTrendChart: View {
    let rows: [SpendingTrendRow]
    let currencyCode: String

    var body: some View {
        if rows.isEmpty {
            ChartEmptyState(systemImage: "chart.line.uptrend.xyaxis", title: "No spending in this period")
        } else {
            Chart(rows) { row in
                AreaMark(
                    x: .value("Date", row.date),
                    y: .value("Amount", row.total)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", row.date),
                    y: .value("Amount", row.total)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", row.date),
                    y: .value("Amount", row.total)
                )
                .foregroundStyle(Color.accentColor)
                .symbolSize(34)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .frame(height: 220)
            .accessibilityLabel("Spending amount trend")
        }
    }
}

private struct CategoryPieChart: View {
    let rows: [(category: ReceiptCategory, total: Decimal)]
    let total: Decimal
    let currencyCode: String

    var body: some View {
        if rows.isEmpty {
            ChartEmptyState(systemImage: "chart.pie", title: "No category data")
        } else {
            VStack(spacing: 14) {
                Chart(rows, id: \.category) { row in
                    SectorMark(
                        angle: .value("Amount", doubleValue(row.total)),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(row.category.color)
                    .accessibilityLabel(row.category.localizedName)
                    .accessibilityValue(row.total.formatted(.currency(code: currencyCode)))
                }
                .chartLegend(.hidden)
                .frame(height: 260)
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        if let frame = proxy.plotFrame {
                            let rect = geometry[frame]
                            VStack(spacing: 2) {
                                Text(total.formatted(.currency(code: currencyCode)))
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: rect.width * 0.56)
                            .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }

                CategoryLegend(rows: rows, currencyCode: currencyCode)
            }
            .accessibilityLabel("Spending category pie chart")
        }
    }

    private func doubleValue(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}

private struct CategoryLegend: View {
    let rows: [(category: ReceiptCategory, total: Decimal)]
    let currencyCode: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(rows, id: \.category) { row in
                HStack(spacing: 7) {
                    Circle()
                        .fill(row.category.color)
                        .frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.category.localizedName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(row.total.formatted(.currency(code: currencyCode)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct ChartEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private enum ReportRange: String, CaseIterable, Identifiable {
    case all
    case thisMonth
    case thisYear
    case custom

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .thisMonth: "This month"
        case .thisYear: "This year"
        case .custom: "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .thisMonth: "calendar"
        case .thisYear: "calendar.badge.clock"
        case .custom: "calendar.badge.plus"
        }
    }
}

private struct ReportRangePicker: View {
    @Binding var range: ReportRange

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReportRange.allCases) { item in
                Button {
                    range = item
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.headline)
                        .frame(width: 42, height: 34)
                        .foregroundStyle(range == item ? Color.white : Color.primary)
                        .background(range == item ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ReportMetricRow: View {
    let title: LocalizedStringKey
    var value: Decimal?
    var valueText: String?
    let systemImage: String
    var currencyCode: String = CurrencyOption.defaultCode

    init(title: LocalizedStringKey, value: Decimal, systemImage: String, currencyCode: String = CurrencyOption.defaultCode) {
        self.title = title
        self.value = value
        self.valueText = nil
        self.systemImage = systemImage
        self.currencyCode = currencyCode
    }

    init(title: LocalizedStringKey, valueText: String, systemImage: String) {
        self.title = title
        self.value = nil
        self.valueText = valueText
        self.systemImage = systemImage
    }

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(valueText ?? value?.formatted(.currency(code: currencyCode)) ?? "")
                .font(.headline)
        }
    }
}

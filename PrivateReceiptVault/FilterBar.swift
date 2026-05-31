import SwiftUI

enum ReceiptDateFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case thisMonth = "Month"
    case thisYear = "Year"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
}

struct FilterBar: View {
    @Binding var category: ReceiptCategory?
    @Binding var dateFilter: ReceiptDateFilter

    var body: some View {
        VStack(spacing: 10) {
            Picker("Date", selection: $dateFilter) {
                ForEach(ReceiptDateFilter.allCases) { filter in
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

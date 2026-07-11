import SwiftUI

struct ReceiptReviewView: View {
    @Binding var draft: ReceiptDraft
    let isRecognizing: Bool
    var showsSaveButton = true
    let saveAction: () -> Void

    @State private var showingFullEdit = false
    @State private var showingFieldDetails = false
    @State private var selectedFieldKey = "total"
    @FocusState private var focusedField: String?

    private var recognizedCount: Int {
        reviewFields.filter { $0.status != .missing }.count
    }

    private var needsAttentionCount: Int {
        reviewFields.filter { $0.status != .recognized }.count
    }

    private var completionText: String {
        "\(recognizedCount)/\(reviewFields.count)"
    }

    private var canSave: Bool {
        !draft.totalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("检查 OCR 字段", systemImage: "text.viewfinder")
                    .font(.headline)
                Spacer()
                Text(completionText)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                if isRecognizing { ProgressView().controlSize(.small) }
            }

            if needsAttentionCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(needsAttentionCount) 个字段需要确认")
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            aiUnderstandingPanel

            quickCorrectionPanel

            DisclosureGroup(isExpanded: $showingFieldDetails) {
                VStack(spacing: 7) {
                    ForEach(reviewFields) { field in
                        ReviewFieldRow(field: field, isSelected: selectedFieldKey == field.key) {
                            selectedFieldKey = field.key
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("更多 OCR 详情", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(10)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

            if showsSaveButton {
                HStack(spacing: 10) {
                    editAllFieldsButton

                    Button(action: saveAction) {
                        Label("Save Receipt", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
            } else {
                editAllFieldsButton
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingFullEdit) {
            NavigationStack {
                ScrollView {
                    ReceiptFormView(draft: $draft)
                        .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Edit Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button("Done") {
                        showingFullEdit = false
                    }
                }
            }
        }
    }

    private var aiUnderstandingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("AI 已理解收据内容", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 7) {
                AIUnderstandingChip(title: "分类", value: draft.category.localizedName, systemImage: draft.category.systemImage, color: draft.category.color)
                AIUnderstandingChip(title: "报销", value: draft.reimbursementStatus.localizedName, systemImage: "briefcase", color: draft.reimbursementStatus == .reimbursable ? .green : .secondary)
            }

            if !draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(draft.notes, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var editAllFieldsButton: some View {
        Button {
            showingFullEdit = true
        } label: {
            Label("Edit all fields", systemImage: "square.and.pencil")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var quickCorrectionPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("快速修正", systemImage: "checklist.checked")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(spacing: 8) {
                TextField("Merchant", text: $draft.merchant)
                    .textContentType(.organizationName)
                    .focused($focusedField, equals: "merchant")

                DatePicker("Date", selection: $draft.date, displayedComponents: .date)

                HStack(spacing: 10) {
                    Picker("Category", selection: $draft.category) {
                        ForEach(ReceiptCategory.allCases) { category in
                            Text(category.localizedName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    CurrencyPicker(currencyCode: $draft.currencyCode)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Picker("报销状态", selection: $draft.reimbursementStatus) {
                    ForEach(ReimbursementStatus.allCases) { status in
                        Text(status.localizedName).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    TextField("实付金额", text: $draft.totalText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "total")

                    TextField("税额", text: $draft.taxText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "tax")
                }

                HStack(spacing: 10) {
                    TextField("小计/税前金额", text: $draft.subtotalText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "subtotal")

                    TextField("Tip", text: $draft.tipText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "tip")
                }

                TextField("AI 备注", text: $draft.notes, axis: .vertical)
                    .lineLimit(1...2)
                    .focused($focusedField, equals: "notes")
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(10)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var reviewFields: [ReviewField] {
        [
            ReviewField(key: "merchant", title: "Merchant", value: draft.merchant, systemImage: "storefront", status: status(for: "merchant", value: draft.merchant)),
            ReviewField(key: "category", title: "Category", value: draft.category.localizedName, systemImage: draft.category.systemImage, status: status(for: "category", value: draft.category == .other ? "" : draft.category.localizedName)),
            ReviewField(key: "date", title: "Date", value: draft.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar", status: status(for: "date", value: draft.date.formatted(date: .abbreviated, time: .omitted))),
            ReviewField(key: "total", title: "实付金额", value: currencyValue(draft.totalText), systemImage: "sum", status: status(for: "total", value: draft.totalText)),
            ReviewField(key: "tax", title: "税额", value: currencyValue(draft.taxText), systemImage: "percent", status: status(for: "tax", value: draft.taxText)),
            ReviewField(key: "subtotal", title: "小计/税前金额", value: currencyValue(draft.subtotalText), systemImage: "list.bullet.rectangle", status: status(for: "subtotal", value: draft.subtotalText)),
            ReviewField(key: "paymentMethod", title: "Payment method", value: draft.paymentMethod, systemImage: "creditcard", status: status(for: "paymentMethod", value: draft.paymentMethod)),
            ReviewField(key: "cardLast4", title: "Card last 4", value: draft.cardLast4, systemImage: "number", status: status(for: "cardLast4", value: draft.cardLast4)),
            ReviewField(key: "receiptNumber", title: "Receipt number", value: draft.receiptNumber, systemImage: "number.square", status: status(for: "receiptNumber", value: draft.receiptNumber)),
            ReviewField(key: "lineItems", title: "Line items", value: draft.lineItems.isEmpty ? "" : "\(draft.lineItems.count)", systemImage: "list.bullet", status: status(for: "lineItems", value: draft.lineItems.isEmpty ? "" : "\(draft.lineItems.count)"))
        ]
    }

    private func currencyValue(_ text: String) -> String {
        guard let decimal = DecimalParser.parse(text) else { return "" }
        return decimal.formatted(.currency(code: draft.currencyCode))
    }

    private func status(for key: String, value: String) -> ReviewFieldStatus {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missing
        }
        if draft.lowConfidenceFieldKeys.contains(key) || !draft.recognizedFieldKeys.contains(key) {
            return .review
        }
        return .recognized
    }

}

private struct ReviewField: Identifiable {
    let id = UUID()
    let key: String
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    var status: ReviewFieldStatus

    init(key: String, title: LocalizedStringKey, value: String, systemImage: String, status: ReviewFieldStatus) {
        self.key = key
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.status = status
    }
}

private struct AIUnderstandingRow: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AIUnderstandingChip: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text("\(title)：\(value)")
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum ReviewFieldStatus {
    case recognized
    case review
    case missing

    var color: Color {
        switch self {
        case .recognized: .green
        case .review: .orange
        case .missing: .secondary
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .recognized: "Recognized"
        case .review: "Check"
        case .missing: "Needs review"
        }
    }

    var systemImage: String {
        switch self {
        case .recognized: "checkmark.seal.fill"
        case .review: "exclamationmark.triangle.fill"
        case .missing: "circle.dashed"
        }
    }
}

private struct ReviewFieldRow: View {
    let field: ReviewField
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: field.systemImage)
                    .foregroundStyle(field.status.color)
                    .frame(width: 30, height: 30)
                    .background(field.status.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(field.value.isEmpty ? String(localized: "Needs review") : field.value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(field.status == .missing ? .secondary : .primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                Label(field.status.label, systemImage: field.status.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(field.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(field.status.color.opacity(0.10), in: Capsule())
                    .accessibilityLabel(field.status.label)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(isSelected ? field.status.color.opacity(0.12) : .secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? field.status.color.opacity(0.65) : .clear, lineWidth: 1)
        }
    }
}

private extension Array where Element == String {
    func ifEmpty(_ fallback: [String]) -> [String] {
        isEmpty ? fallback : self
    }

    func prefixArray(_ maxLength: Int) -> [String] {
        Array(prefix(maxLength))
    }
}

private extension String {
    var containsAmount: Bool {
        range(of: #"\d+[.]\d{2}"#, options: .regularExpression) != nil
    }
}

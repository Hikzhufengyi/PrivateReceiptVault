import SwiftUI

struct AddReviewViewController: View {
    @Binding var draft: ReceiptDraft
    @Binding var confirmedLowConfidenceFieldKeys: Set<String>
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
        unresolvedReviewFields.count
    }

    private var completionText: String {
        "\(recognizedCount)/\(reviewFields.count)"
    }

    private var canSave: Bool {
        !draft.totalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unresolvedReviewFields.isEmpty
    }

    private var unresolvedReviewFields: [ReviewField] {
        reviewFields.filter { $0.status == .review }
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
                    Text("\(needsAttentionCount) 个字段需要核对")
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            if !unresolvedReviewFields.isEmpty {
                confirmationPanel
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
                        Label(canSave ? "确认并保存" : "请先核对待确认字段", systemImage: "checkmark.circle")
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
                    AddViewController(draft: $draft)
                        .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("编辑收据")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button("完成") {
                        showingFullEdit = false
                    }
                }
            }
        }
    }

    private var aiUnderstandingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("已识别摘要", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 7) {
                AIUnderstandingChip(title: "分类", value: draft.category.localizedName, systemImage: draft.category.systemImage, color: draft.category.color)
                AIUnderstandingChip(title: "报销", value: draft.reimbursementStatus.localizedName, systemImage: "briefcase", color: draft.reimbursementStatus == .reimbursable ? .green : .secondary)
            }

            if !draft.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(draft.paymentMethod, systemImage: "creditcard")
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
            Label("编辑全部字段", systemImage: "square.and.pencil")
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
                reviewTextField("商户", key: "merchant", text: $draft.merchant, isAmount: false)
                    .textContentType(.organizationName)

                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel("日期", key: "date")
                    DatePicker("日期", selection: $draft.date, displayedComponents: .date)
                        .onChange(of: draft.date) { _ in
                            confirmedLowConfidenceFieldKeys.remove("date")
                        }
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        fieldLabel("分类", key: "category")
                        Picker("分类", selection: $draft.category) {
                        ForEach(ReceiptCategory.allCases) { category in
                            Text(category.localizedName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        fieldLabel("收据币种", key: "currency")
                        CurrencyPicker(currencyCode: $draft.currencyCode)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: draft.currencyCode) { _ in
                                confirmedLowConfidenceFieldKeys.remove("currency")
                            }
                    }
                }

                Picker("报销状态", selection: $draft.reimbursementStatus) {
                    ForEach(ReimbursementStatus.allCases) { status in
                        Text(status.localizedName).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    reviewTextField("总额", key: "total", text: $draft.totalText)
                    reviewTextField("税额", key: "tax", text: $draft.taxText)
                }

                HStack(spacing: 10) {
                    reviewTextField("小计（税前）", key: "subtotal", text: $draft.subtotalText)
                    reviewTextField("小费", key: "tip", text: $draft.tipText)
                }

                TextField("备注", text: $draft.notes, axis: .vertical)
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
            ReviewField(key: "merchant", title: "商户", value: draft.merchant, systemImage: "storefront", status: status(for: "merchant", value: draft.merchant)),
            ReviewField(key: "category", title: "分类", value: draft.category.localizedName, systemImage: draft.category.systemImage, status: status(for: "category", value: draft.category == .other ? "" : draft.category.localizedName)),
            ReviewField(key: "date", title: "日期", value: draft.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar", status: status(for: "date", value: draft.date.formatted(date: .abbreviated, time: .omitted))),
            ReviewField(key: "currency", title: "收据币种", value: draft.currencyCode, systemImage: "banknote", status: status(for: "currency", value: draft.currencyCode)),
            ReviewField(key: "total", title: "总额", value: currencyValue(draft.totalText), systemImage: "sum", status: status(for: "total", value: draft.totalText)),
            ReviewField(key: "tax", title: "税额", value: currencyValue(draft.taxText), systemImage: "percent", status: status(for: "tax", value: draft.taxText)),
            ReviewField(key: "subtotal", title: "小计（税前）", value: currencyValue(draft.subtotalText), systemImage: "list.bullet.rectangle", status: status(for: "subtotal", value: draft.subtotalText)),
            ReviewField(key: "paymentMethod", title: "支付方式", value: draft.paymentMethod, systemImage: "creditcard", status: status(for: "paymentMethod", value: draft.paymentMethod)),
            ReviewField(key: "cardLast4", title: "卡号后四位", value: draft.cardLast4, systemImage: "number", status: status(for: "cardLast4", value: draft.cardLast4)),
            ReviewField(key: "receiptNumber", title: "收据编号", value: draft.receiptNumber, systemImage: "number.square", status: status(for: "receiptNumber", value: draft.receiptNumber)),
            ReviewField(key: "lineItems", title: "商品明细", value: draft.lineItems.isEmpty ? "" : "\(draft.lineItems.count)", systemImage: "list.bullet", status: status(for: "lineItems", value: draft.lineItems.isEmpty ? "" : "\(draft.lineItems.count)"))
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
            if confirmedLowConfidenceFieldKeys.contains(key) {
                return .confirmed
            }
            return .review
        }
        return .recognized
    }

    private var confirmationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("请对照原收据逐项确认")
                .font(.subheadline.weight(.semibold))
            ForEach(unresolvedReviewFields) { field in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.title)
                            .font(.caption.weight(.semibold))
                        Text(confirmationReason(for: field.key))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("已核对") {
                        confirmedLowConfidenceFieldKeys.insert(field.key)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(10)
        .background(.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private func confirmationReason(for key: String) -> String {
        ["total", "tax", "subtotal"].contains(key)
            ? "金额关系需要与原收据核对"
            : "OCR 识别结果需要与原收据核对"
    }

    private func fieldLabel(_ title: String, key: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if status(for: key, value: value(for: key)) == .review {
                Label("需核对", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if confirmedLowConfidenceFieldKeys.contains(key) {
                Label("已核对", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }

    private func reviewTextField(_ title: String, key: String, text: Binding<String>, isAmount: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(title, key: key)
            TextField(title, text: text)
                .keyboardType(isAmount ? .decimalPad : .default)
                .focused($focusedField, equals: key)
                .onChange(of: text.wrappedValue) { _ in
                    confirmedLowConfidenceFieldKeys.remove(key)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func value(for key: String) -> String {
        switch key {
        case "merchant": draft.merchant
        case "currency": draft.currencyCode
        case "total": draft.totalText
        case "tax": draft.taxText
        case "subtotal": draft.subtotalText
        case "tip": draft.tipText
        default: ""
        }
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
    case confirmed
    case review
    case missing

    var color: Color {
        switch self {
        case .recognized, .confirmed: .green
        case .review: .orange
        case .missing: .secondary
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .recognized: "Recognized"
        case .confirmed: "Confirmed"
        case .review: "Check"
        case .missing: "Needs review"
        }
    }

    var systemImage: String {
        switch self {
        case .recognized: "checkmark.seal.fill"
        case .confirmed: "checkmark.circle.fill"
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

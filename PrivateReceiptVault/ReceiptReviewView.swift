import SwiftUI

struct ReceiptReviewView: View {
    @Binding var draft: ReceiptDraft
    let isRecognizing: Bool
    let saveAction: () -> Void

    @State private var showingFullEdit = false
    @State private var showingFieldDetails = false
    @State private var showingSourceText = false
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.18), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: CGFloat(recognizedCount) / CGFloat(max(reviewFields.count, 1)))
                        .stroke(.tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(completionText)
                        .font(.caption.bold())
                        .monospacedDigit()
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Review OCR fields")
                        .font(.headline)
                    Text("Confirm the extracted fields before saving.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isRecognizing {
                    ProgressView()
                }
            }

            if needsAttentionCount > 0 {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Confirm highlighted fields")
                            .font(.subheadline.weight(.semibold))
                        Text("Low-confidence or missing values are marked before saving.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(needsAttentionCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12), in: Capsule())
                }
                .padding(10)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            quickCorrectionPanel

            DisclosureGroup(isExpanded: $showingFieldDetails) {
                VStack(spacing: 10) {
                    ForEach(reviewFields) { field in
                        ReviewFieldRow(field: field, isSelected: selectedFieldKey == field.key) {
                            selectedFieldKey = field.key
                        }
                    }
                }
                .padding(.top, 10)
            } label: {
                Label("Review extracted details", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

            DisclosureGroup(isExpanded: $showingSourceText) {
                sourceLinesPanel
                    .padding(.top, 10)
            } label: {
                Label("Possible source text", systemImage: "text.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button {
                    showingFullEdit = true
                } label: {
                    Label("Edit all fields", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: saveAction) {
                    Label("Save Receipt", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingFullEdit) {
            NavigationStack {
                ScrollView {
                    ReceiptFormView(draft: $draft)
                        .padding()
                }
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

    private var quickCorrectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Quick corrections", systemImage: "checklist.checked")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("On-device only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 10) {
                TextField("Merchant", text: $draft.merchant)
                    .textContentType(.organizationName)
                    .focused($focusedField, equals: "merchant")

                DatePicker("Date", selection: $draft.date, displayedComponents: .date)

                HStack(spacing: 10) {
                    TextField("Total", text: $draft.totalText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "total")

                    TextField("Tax", text: $draft.taxText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "tax")
                }

                HStack(spacing: 10) {
                    TextField("Subtotal", text: $draft.subtotalText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "subtotal")

                    TextField("Tip", text: $draft.tipText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "tip")
                }
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var sourceLinesPanel: some View {
        let field = reviewFields.first { $0.key == selectedFieldKey } ?? reviewFields.first
        let lines = sourceLines(for: field?.key ?? "")

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OCR lines")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let field {
                    Text(field.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(field.status.color)
                }
            }

            if lines.isEmpty {
                Text("No matching OCR line found. Check the image or enter the value manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 7) {
                    ForEach(lines.prefix(4), id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(line)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var reviewFields: [ReviewField] {
        [
            ReviewField(key: "merchant", title: "Merchant", value: draft.merchant, systemImage: "storefront", status: status(for: "merchant", value: draft.merchant)),
            ReviewField(key: "date", title: "Date", value: draft.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar", status: status(for: "date", value: draft.date.formatted(date: .abbreviated, time: .omitted))),
            ReviewField(key: "total", title: "Total", value: currencyValue(draft.totalText), systemImage: "sum", status: status(for: "total", value: draft.totalText)),
            ReviewField(key: "tax", title: "Tax", value: currencyValue(draft.taxText), systemImage: "percent", status: status(for: "tax", value: draft.taxText)),
            ReviewField(key: "subtotal", title: "Subtotal", value: currencyValue(draft.subtotalText), systemImage: "list.bullet.rectangle", status: status(for: "subtotal", value: draft.subtotalText)),
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

    private func sourceLines(for key: String) -> [String] {
        let lines = draft.recognizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        let keywords: [String]
        switch key {
        case "merchant":
            let merchant = draft.merchant.lowercased()
            return lines.filter { line in
                let lower = line.lowercased()
                return !merchant.isEmpty && (lower.contains(merchant) || merchant.contains(lower))
            }.ifEmpty(Array(lines.prefix(3)))
        case "date":
            keywords = ["date", "time"]
        case "total":
            keywords = ["grand total", "amount due", "balance due", "total due", "total", "balance", "paid"]
        case "tax":
            keywords = ["sales tax", "tax", "vat", "gst", "hst", "pst"]
        case "subtotal":
            keywords = ["subtotal", "sub total", "sub-total", "net total", "amount"]
        case "paymentMethod":
            keywords = ["visa", "mastercard", "master card", "amex", "american express", "discover", "cash", "apple pay"]
        case "cardLast4":
            keywords = ["ending", "last 4", "card", "visa", "mastercard", "amex"]
        case "receiptNumber":
            keywords = ["receipt", "check", "order", "invoice"]
        case "lineItems":
            return lines.filter(\.containsAmount).prefixArray(4)
        default:
            keywords = []
        }

        let matches = lines.filter { line in
            let lower = line.lowercased()
            return keywords.contains { lower.contains($0) }
        }
        if !matches.isEmpty { return matches }

        let value = valueForSourceLookup(key: key)
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return [] }
        return lines.filter { line in
            line.lowercased().replacingOccurrences(of: ",", with: "").contains(value)
        }
    }

    private func valueForSourceLookup(key: String) -> String {
        switch key {
        case "merchant": draft.merchant
        case "total": draft.totalText
        case "tax": draft.taxText
        case "subtotal": draft.subtotalText
        case "paymentMethod": draft.paymentMethod
        case "cardLast4": draft.cardLast4
        case "receiptNumber": draft.receiptNumber
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

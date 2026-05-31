import SwiftUI

struct ReceiptDetailView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var receipt: Receipt
    @State private var subtotalText: String
    @State private var totalText: String
    @State private var taxText: String
    @State private var taxRateText: String
    @State private var tipText: String

    init(receipt: Receipt) {
        _receipt = State(initialValue: receipt)
        _subtotalText = State(initialValue: receipt.subtotal.map { "\($0)" } ?? "")
        _totalText = State(initialValue: "\(receipt.total)")
        _taxText = State(initialValue: receipt.tax.map { "\($0)" } ?? "")
        _taxRateText = State(initialValue: receipt.taxRate.map { "\($0)" } ?? "")
        _tipText = State(initialValue: receipt.tip.map { "\($0)" } ?? "")
    }

    var body: some View {
        Form {
            if let fileName = receipt.imageFileName,
               let image = UIImage(contentsOfFile: store.imageURL(for: fileName).path) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                }
            }

            Section("Receipt") {
                TextField("Merchant", text: $receipt.merchant)
                DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
                TextField("Subtotal", text: $subtotalText)
                    .keyboardType(.decimalPad)
                TextField("Total", text: $totalText)
                    .keyboardType(.decimalPad)
                TextField("Tax", text: $taxText)
                    .keyboardType(.decimalPad)
                TextField("Tax rate %", text: $taxRateText)
                    .keyboardType(.decimalPad)
                TextField("Tip", text: $tipText)
                    .keyboardType(.decimalPad)
                CurrencyPicker(currencyCode: $receipt.currencyCode)
            }

            Section("Organization") {
                Picker("Category", selection: $receipt.category) {
                    ForEach(ReceiptCategory.allCases) { category in
                        Text(category.localizedName).tag(category)
                    }
                }
                TextField("Project or client", text: $receipt.project)
                TextField("Payment method", text: $receipt.paymentMethod)
                TextField("Card last 4", text: $receipt.cardLast4)
                    .keyboardType(.numberPad)
                TextField("Transaction ID", text: $receipt.transactionID)
                TextField("Receipt number", text: $receipt.receiptNumber)
                TextField("Store address", text: $receipt.storeAddress, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
                TextField("Notes", text: $receipt.notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            if !receipt.lineItems.isEmpty {
                Section("Line Items") {
                    ForEach(receipt.lineItems) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            if let amount = item.amount {
                                Text(amount.formatted(.currency(code: receipt.currencyCode)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !receipt.recognizedText.isEmpty {
                Section("Recognized Text") {
                    Text(receipt.recognizedText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Save") {
                receipt.subtotal = DecimalParser.parse(subtotalText)
                receipt.total = DecimalParser.parse(totalText) ?? 0
                receipt.tax = DecimalParser.parse(taxText)
                receipt.taxRate = DecimalParser.parse(taxRateText.replacingOccurrences(of: "%", with: ""))
                receipt.tip = DecimalParser.parse(tipText)
                receipt.currencyCode = receipt.currencyCode.uppercased()
                store.update(receipt)
            }
        }
    }
}

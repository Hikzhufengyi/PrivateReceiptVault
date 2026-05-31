import SwiftUI

struct ReceiptFormView: View {
    @Binding var draft: ReceiptDraft

    var body: some View {
        VStack(spacing: 18) {
            GroupBox("Receipt") {
                VStack(spacing: 12) {
                    TextField("Merchant", text: $draft.merchant)
                        .textContentType(.organizationName)

                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)

                    TextField("Subtotal", text: $draft.subtotalText)
                        .keyboardType(.decimalPad)

                    TextField("Total", text: $draft.totalText)
                        .keyboardType(.decimalPad)

                    TextField("Tax", text: $draft.taxText)
                        .keyboardType(.decimalPad)

                    TextField("Tax rate %", text: $draft.taxRateText)
                        .keyboardType(.decimalPad)

                    TextField("Tip", text: $draft.tipText)
                        .keyboardType(.decimalPad)

                    CurrencyPicker(currencyCode: $draft.currencyCode)
                }
                .textFieldStyle(.roundedBorder)
            }

            GroupBox("Organization") {
                VStack(spacing: 12) {
                    Picker("Category", selection: $draft.category) {
                        ForEach(ReceiptCategory.allCases) { category in
                            Text(category.localizedName).tag(category)
                        }
                    }

                    TextField("Project or client", text: $draft.project)
                        .textFieldStyle(.roundedBorder)

                    TextField("Payment method", text: $draft.paymentMethod)
                        .textFieldStyle(.roundedBorder)

                    TextField("Card last 4", text: $draft.cardLast4)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Transaction ID", text: $draft.transactionID)
                        .textFieldStyle(.roundedBorder)

                    TextField("Receipt number", text: $draft.receiptNumber)
                        .textFieldStyle(.roundedBorder)

                    TextField("Store address", text: $draft.storeAddress, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                        .textFieldStyle(.roundedBorder)

                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if !draft.lineItems.isEmpty {
                GroupBox("Line Items") {
                    VStack(spacing: 10) {
                        ForEach(draft.lineItems) { item in
                            HStack {
                                Text(item.name)
                                    .lineLimit(1)
                                Spacer()
                                if let amount = item.amount {
                                    Text(amount.formatted(.currency(code: draft.currencyCode)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }

            if !draft.recognizedText.isEmpty {
                GroupBox("Recognized Text") {
                    Text(draft.recognizedText)
                        .font(.footnote.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

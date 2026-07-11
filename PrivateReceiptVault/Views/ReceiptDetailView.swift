import SwiftUI

struct ReceiptDetailView: View {
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var receipt: Receipt
    @State private var subtotalText: String
    @State private var totalText: String
    @State private var taxText: String
    @State private var taxRateText: String
    @State private var tipText: String
    @State private var showingSavedAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingImagePreview = false

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
            if let image = receiptImage {
                Section {
                    Button {
                        showingImagePreview = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Receipt") {
                TextField("Merchant", text: $receipt.merchant)
                DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
                TextField("小计/税前金额", text: $subtotalText)
                    .keyboardType(.decimalPad)
                TextField("实付金额", text: $totalText)
                    .keyboardType(.decimalPad)
                TextField("税额", text: $taxText)
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
                Picker("报销状态", selection: reimbursementStatusBinding) {
                    ForEach(ReimbursementStatus.allCases) { status in
                        Text(status.localizedName).tag(status)
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

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("删除收据", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveReceipt()
                }
            }
        }
        .alert("保存成功", isPresented: $showingSavedAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("收据已更新。")
        }
        .alert("删除收据？", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                store.delete(receipt)
                dismiss()
            }
        } message: {
            Text("删除后会同时移除这张收据的图片。")
        }
        .fullScreenCover(isPresented: $showingImagePreview) {
            if let image = receiptImage {
                ZoomableReceiptImageView(image: image)
            }
        }
    }

    private var receiptImage: UIImage? {
        guard let fileName = receipt.imageFileName else { return nil }
        return UIImage(contentsOfFile: store.imageURL(for: fileName).path)
    }

    private func saveReceipt() {
        receipt.subtotal = DecimalParser.parse(subtotalText)
        receipt.total = DecimalParser.parse(totalText) ?? 0
        receipt.tax = DecimalParser.parse(taxText)
        receipt.taxRate = DecimalParser.parse(taxRateText.replacingOccurrences(of: "%", with: ""))
        receipt.tip = DecimalParser.parse(tipText)
        receipt.currencyCode = receipt.currencyCode.uppercased()
        store.update(receipt)
        showingSavedAlert = true
    }

    private var reimbursementStatusBinding: Binding<ReimbursementStatus> {
        Binding(
            get: { receipt.reimbursementState },
            set: { receipt.reimbursementStatus = $0 }
        )
    }
}

private struct ZoomableReceiptImageView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissDragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(x: offset.width, y: offset.height + dismissDragOffset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value, 1), 5)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale == 1 {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            } else {
                                dismissDragOffset = max(0, value.translation.height)
                            }
                        }
                        .onEnded { _ in
                            if scale > 1 {
                                lastOffset = offset
                            } else if dismissDragOffset > 120 {
                                dismiss()
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    dismissDragOffset = 0
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    if scale > 1 {
                        scale = 1
                        lastScale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel("关闭")
        }
    }

    private var backgroundOpacity: Double {
        max(0.35, 1 - Double(dismissDragOffset / 320))
    }
}

import SwiftUI
import UIKit

struct ScanView: View {
    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var proAccess: ProAccess
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ReceiptDraft()
    @State private var selectedImage: UIImage?
    @State private var originalImageForEditing: UIImage?
    @State private var processedImageForEditing: UIImage?
    @State private var processedAutoCropped = false
    @State private var activePickerSource: ImagePicker.Source?
    @State private var showingImageEditor = false
    @State private var showingPaywall = false
    @State private var duplicateCandidates: [Receipt] = []
    @State private var showingDuplicateAlert = false
    @State private var isRecognizing = false
    @State private var recognitionError: String?
    @State private var showingNoReceiptAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if selectedImage == nil {
                        imagePreview
                        TrustBadgesView(compact: true)
                    }

                    scanSourceButtons
                    selectedImageActions

                    if selectedImage != nil {
                        ReceiptReviewView(draft: $draft, isRecognizing: isRecognizing, showsSaveButton: false) {
                            save()
                        }
                    }
                }
                .padding()
                .padding(.bottom, selectedImage == nil ? 0 : 92)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $activePickerSource) { source in
                ImagePicker(source: source) { image in
                    processSelectedImage(image)
                }
            }
            .sheet(isPresented: $showingImageEditor) {
                if let originalImageForEditing, let processedImageForEditing {
                    ReceiptImageEditorView(
                        originalImage: originalImageForEditing,
                        processedImage: processedImageForEditing,
                        autoCropped: processedAutoCropped
                    ) { editedImage in
                        applyEditedImage(editedImage)
                    }
                }
            }
            .alert("OCR failed", isPresented: Binding(
                get: { recognitionError != nil },
                set: { if !$0 { recognitionError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(recognitionError ?? "")
            }
            .alert("没有识别到收据", isPresented: $showingNoReceiptAlert) {
                Button("重新拍照") {
                    activePickerSource = .camera
                }
                Button("从相册选择") {
                    activePickerSource = .photoLibrary
                }
                Button("继续手动填写", role: .cancel) {}
            } message: {
                Text("这张图片没有识别出收据的关键字段。请让收据边缘完整、文字清晰后重新拍照，或从相册选择更清楚的图片。")
            }
            .alert("Possible duplicate", isPresented: $showingDuplicateAlert) {
                Button("Save Anyway") {
                    store.add(from: draft)
                    dismiss()
                }
                Button("Review", role: .cancel) {}
            } message: {
                Text("The scanned fields match an existing receipt: \(duplicateCandidates.first?.merchant ?? "existing receipt"), same date and amount. Review before saving again.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .safeAreaInset(edge: .bottom) {
                if selectedImage != nil {
                    bottomSaveBar
                }
            }
        }
    }

    private var canSaveReceipt: Bool {
        !draft.totalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var bottomSaveBar: some View {
        VStack(spacing: 10) {
            Button {
                save()
            } label: {
                Label("Save Receipt", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSaveReceipt || isRecognizing)

            if isRecognizing {
                Text("AI 正在识别...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var scanSourceButtons: some View {
        HStack(spacing: 12) {
            Button {
                activePickerSource = .camera
            } label: {
                Label(selectedImage == nil ? "Camera" : "Rescan", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                activePickerSource = .photoLibrary
            } label: {
                Label(selectedImage == nil ? "Import" : "Replace image", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var selectedImageActions: some View {
        if let selectedImage {
            HStack(spacing: 10) {
                Label(isRecognizing ? "AI 正在识别" : "图片已添加", systemImage: isRecognizing ? "text.viewfinder" : "photo.badge.checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isRecognizing ? Color.secondary : Color.green)

                Spacer()

                if isRecognizing {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    if originalImageForEditing == nil {
                        originalImageForEditing = selectedImage
                    }
                    processedImageForEditing = selectedImage
                    showingImageEditor = true
                } label: {
                    Label("裁剪", systemImage: "crop.rotate")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRecognizing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let selectedImage {
            VStack(spacing: 10) {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .center) {
                        if isRecognizing {
                            ProgressView("Reading receipt")
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                Button {
                    if originalImageForEditing == nil {
                        originalImageForEditing = selectedImage
                    }
                    processedImageForEditing = selectedImage
                    showingImageEditor = true
                } label: {
                    Label("Crop / Rotate", systemImage: "crop.rotate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 42))
                    .foregroundStyle(.tint)
                Text("拍一张照片")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI自动提取：")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 7) {
                        ForEach(["商户", "日期", "金额", "税额", "商品明细"], id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .frame(maxWidth: 260, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 240)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func recognize(_ image: UIImage, fallbackImage: UIImage? = nil) {
        isRecognizing = true
        Task {
            do {
                let images = fallbackImage.map { [image, $0] } ?? [image]
                let result = try await OCRService.recognize(images: images)
                await MainActor.run {
                    draft.recognizedText = result.text
                    if !result.merchant.isEmpty { draft.merchant = result.merchant }
                    if !result.subtotalText.isEmpty { draft.subtotalText = result.subtotalText }
                    if !result.totalText.isEmpty { draft.totalText = result.totalText }
                    if !result.taxText.isEmpty { draft.taxText = result.taxText }
                    if !result.taxRateText.isEmpty { draft.taxRateText = result.taxRateText }
                    if !result.tipText.isEmpty { draft.tipText = result.tipText }
                    if let date = result.date { draft.date = date }
                    if !result.paymentMethod.isEmpty { draft.paymentMethod = result.paymentMethod }
                    if !result.cardLast4.isEmpty { draft.cardLast4 = result.cardLast4 }
                    if !result.transactionID.isEmpty { draft.transactionID = result.transactionID }
                    if !result.storeAddress.isEmpty { draft.storeAddress = result.storeAddress }
                    if !result.receiptNumber.isEmpty { draft.receiptNumber = result.receiptNumber }
                    if let currencyCode = result.currencyCode { draft.currencyCode = currencyCode }
                    draft.recognizedFieldKeys = result.recognizedFieldKeys
                    draft.lowConfidenceFieldKeys = result.lowConfidenceFieldKeys
                    draft.lineItems = result.lineItems
                    draft.reconcileAmountsKeepingTotal()
                    applyAIUnderstanding(from: result)
                    showingNoReceiptAlert = isClearlyNotReceipt(result)
                    isRecognizing = false
                }
            } catch {
                await MainActor.run {
                    recognitionError = "\(error.localizedDescription)\n\nTry better lighting, flatten the receipt, keep all edges visible, then scan again."
                    isRecognizing = false
                }
            }
        }
    }

    private func isClearlyNotReceipt(_ result: OCRResult) -> Bool {
        result.totalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            result.taxText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            result.subtotalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            result.date == nil &&
            result.lineItems.isEmpty &&
            result.text.components(separatedBy: .newlines).count < 4
    }

    private func save() {
        guard proAccess.canAddReceipt(currentCount: store.receipts.count) else {
            showingPaywall = true
            return
        }

        draft.reconcileAmountsKeepingTotal()
        duplicateCandidates = store.duplicateCandidates(for: draft)
        if !duplicateCandidates.isEmpty {
            showingDuplicateAlert = true
            return
        }

        store.add(from: draft)
        dismiss()
    }

    private func processSelectedImage(_ image: UIImage) {
        isRecognizing = true
        Task {
            let processed = await ImageEnhancementService.processReceiptImage(from: image)
            await MainActor.run {
                originalImageForEditing = image
                processedImageForEditing = processed.image
                processedAutoCropped = processed.autoCropped
                selectedImage = processed.image
                draft.imageData = processed.image.jpegData(compressionQuality: 0.88)
            }
            recognize(processed.image, fallbackImage: image)
        }
    }

    private func applyEditedImage(_ image: UIImage) {
        selectedImage = image
        draft.imageData = image.jpegData(compressionQuality: 0.88)
        recognize(image)
    }

    private func applyAIUnderstanding(from result: OCRResult) {
        let understanding = ReceiptAIService.understand(result: result, currentDraft: draft)
        draft.category = understanding.category
        draft.reimbursementStatus = understanding.reimbursementStatus
        if draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.notes = understanding.notes
        }
        draft.recognizedFieldKeys.insert("category")
        if !draft.notes.isEmpty {
            draft.recognizedFieldKeys.insert("notes")
        }
        draft.recognizedFieldKeys.insert("reimbursementStatus")
    }
}

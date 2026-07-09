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
    @State private var continuousMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    imagePreview
                    TrustBadgesView(compact: true)

                    scanSourceButtons

                    Toggle(isOn: $continuousMode) {
                        Label("Continuous scan", systemImage: "rectangle.stack.badge.plus")
                    }
                    .toggleStyle(.switch)

                    if selectedImage != nil {
                        ReceiptReviewView(draft: $draft, isRecognizing: isRecognizing) {
                            save()
                        }
                    }
                }
                .padding()
            }
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
            .alert("Possible duplicate", isPresented: $showingDuplicateAlert) {
                Button("Save Anyway") {
                    store.add(from: draft)
                    if continuousMode {
                        resetForNextReceipt()
                    } else {
                        dismiss()
                    }
                }
                Button("Review", role: .cancel) {}
            } message: {
                Text("This looks similar to \(duplicateCandidates.first?.merchant ?? "an existing receipt") on the same date with the same amount.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
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
                Text("Scan a receipt or import a photo")
                    .font(.headline)
                Text("Review extracted fields before saving.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func recognize(_ image: UIImage) {
        isRecognizing = true
        Task {
            do {
                let result = try await OCRService.recognize(image: image)
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

    private func save() {
        guard proAccess.canAddReceipt(currentCount: store.receipts.count) else {
            showingPaywall = true
            return
        }

        duplicateCandidates = store.duplicateCandidates(for: draft)
        if !duplicateCandidates.isEmpty {
            showingDuplicateAlert = true
            return
        }

        store.add(from: draft)
        if continuousMode {
            resetForNextReceipt()
            activePickerSource = .camera
        } else {
            dismiss()
        }
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
            recognize(processed.image)
        }
    }

    private func resetForNextReceipt() {
        draft = ReceiptDraft()
        selectedImage = nil
        originalImageForEditing = nil
        processedImageForEditing = nil
        processedAutoCropped = false
    }

    private func applyEditedImage(_ image: UIImage) {
        selectedImage = image
        draft.imageData = image.jpegData(compressionQuality: 0.88)
        recognize(image)
    }
}

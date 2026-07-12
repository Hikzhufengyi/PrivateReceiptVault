import SwiftUI
import UIKit

struct ImageEditorViewController: View {
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage
    @State private var cropInset: Double = 0
    @State private var autoCropped: Bool

    let originalImage: UIImage
    let onUse: (UIImage) -> Void

    init(originalImage: UIImage, processedImage: UIImage, autoCropped: Bool, onUse: @escaping (UIImage) -> Void) {
        self.originalImage = originalImage
        self.onUse = onUse
        _image = State(initialValue: processedImage)
        _autoCropped = State(initialValue: autoCropped)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 420)
                    .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Label(autoCropped ? "Auto edge crop applied" : "No edge crop found", systemImage: autoCropped ? "checkmark.rectangle" : "rectangle.dashed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Manual crop")
                        .font(.caption.weight(.semibold))
                    Slider(value: $cropInset, in: 0...0.28)
                }

                HStack(spacing: 12) {
                    Button {
                        image = ImageEnhancementService.rotate(previewImage)
                        cropInset = 0
                    } label: {
                        Label("Rotate", systemImage: "rotate.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            let processed = await ImageEnhancementService.processReceiptImage(from: originalImage)
                            image = processed.image
                            autoCropped = processed.autoCropped
                            cropInset = 0
                        }
                    } label: {
                        Label("Auto crop", systemImage: "crop")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        image = originalImage
                        autoCropped = false
                        cropInset = 0
                    } label: {
                        Label("Original", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Adjust Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        onUse(previewImage)
                        dismiss()
                    }
                }
            }
        }
    }

    private var previewImage: UIImage {
        guard cropInset > 0 else { return image }
        return ImageEnhancementService.centerCrop(image, insetRatio: cropInset)
    }
}

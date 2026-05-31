import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    enum Source: Identifiable {
        case camera
        case photoLibrary

        var id: String {
            switch self {
            case .camera: "camera"
            case .photoLibrary: "photoLibrary"
            }
        }

        var uiSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera: .camera
            case .photoLibrary: .photoLibrary
            }
        }
    }

    let source: Source
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(source.uiSourceType) ? source.uiSourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

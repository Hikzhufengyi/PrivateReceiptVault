import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

enum ImageEnhancementService {
    struct ProcessedReceiptImage {
        var image: UIImage
        var autoCropped: Bool
    }

    static func enhancedReceiptImage(from image: UIImage) async -> UIImage {
        await processReceiptImage(from: image).image
    }

    static func processReceiptImage(from image: UIImage) async -> ProcessedReceiptImage {
        await MainActor.run {
            guard let ciImage = CIImage(image: image) else {
                return ProcessedReceiptImage(image: image, autoCropped: false)
            }
            let normalized = ciImage.oriented(forExifOrientation: exifOrientation(for: image.imageOrientation))
            let detected = perspectiveCorrectedImage(from: normalized) ?? normalized
            let enhanced = enhance(detected) ?? detected
            let context = CIContext()
            guard let cgImage = context.createCGImage(enhanced, from: enhanced.extent) else {
                return ProcessedReceiptImage(image: image, autoCropped: false)
            }
            return ProcessedReceiptImage(
                image: UIImage(cgImage: cgImage, scale: image.scale, orientation: .up),
                autoCropped: detected.extent != normalized.extent
            )
        }
    }

    static func rotate(_ image: UIImage, clockwise: Bool = true) -> UIImage {
        let radians = clockwise ? CGFloat.pi / 2 : -CGFloat.pi / 2
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: radians)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        }
    }

    static func centerCrop(_ image: UIImage, insetRatio: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let clamped = min(max(insetRatio, 0), 0.35)
        let insetX = CGFloat(cgImage.width) * clamped
        let insetY = CGFloat(cgImage.height) * clamped
        let rect = CGRect(
            x: insetX,
            y: insetY,
            width: CGFloat(cgImage.width) - insetX * 2,
            height: CGFloat(cgImage.height) - insetY * 2
        ).integral
        guard let cropped = cgImage.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private static func perspectiveCorrectedImage(from image: CIImage) -> CIImage? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.55
        request.minimumAspectRatio = 0.18
        request.quadratureTolerance = 25

        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let rectangle = request.results?.first else { return nil }

        let width = image.extent.width
        let height = image.extent.height
        let correction = CIFilter.perspectiveCorrection()
        correction.inputImage = image
        correction.topLeft = CGPoint(x: rectangle.topLeft.x * width, y: rectangle.topLeft.y * height)
        correction.topRight = CGPoint(x: rectangle.topRight.x * width, y: rectangle.topRight.y * height)
        correction.bottomLeft = CGPoint(x: rectangle.bottomLeft.x * width, y: rectangle.bottomLeft.y * height)
        correction.bottomRight = CGPoint(x: rectangle.bottomRight.x * width, y: rectangle.bottomRight.y * height)
        return correction.outputImage
    }

    private static func enhance(_ image: CIImage) -> CIImage? {
        let color = CIFilter.colorControls()
        color.inputImage = image
        color.contrast = 1.22
        color.brightness = 0.04
        color.saturation = 0.9

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = color.outputImage
        sharpen.sharpness = 0.55
        return sharpen.outputImage
    }

    private static func exifOrientation(for orientation: UIImage.Orientation) -> Int32 {
        switch orientation {
        case .up: return 1
        case .upMirrored: return 2
        case .down: return 3
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .right: return 6
        case .rightMirrored: return 7
        case .left: return 8
        @unknown default: return 1
        }
    }
}

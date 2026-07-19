import AppKit
import Foundation
import Vision

private struct VisionPass {
    let languages: [String]
    let automaticallyDetectsLanguage: Bool
}

private let passes = [
    VisionPass(languages: ["zh-Hans", "en-US"], automaticallyDetectsLanguage: true),
    VisionPass(languages: ["ja-JP", "en-US"], automaticallyDetectsLanguage: false),
    VisionPass(languages: ["ko-KR", "en-US"], automaticallyDetectsLanguage: false),
    VisionPass(languages: ["ar-SA", "en-US"], automaticallyDetectsLanguage: false),
    VisionPass(languages: ["de-DE", "es-ES", "fr-FR", "it-IT", "nl-NL", "pt-BR", "en-US"], automaticallyDetectsLanguage: false)
]

private func recognizeLines(in imageURL: URL, pass: VisionPass) throws -> [OCRRecognizedLine] {
    guard let image = NSImage(contentsOf: imageURL), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "OCRImageIntegrationRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode image"])
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = pass.languages
    request.automaticallyDetectsLanguage = pass.automaticallyDetectsLanguage

    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])
    return request.results?.compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return OCRRecognizedLine(text: text, boundingBox: observation.boundingBox, confidence: candidate.confidence)
    } ?? []
}

private func bestResult(for imageURL: URL) throws -> (OCRResult, [OCRRecognizedLine], Int) {
    var firstResult: (OCRResult, [OCRRecognizedLine], Int)?
    for (index, pass) in passes.enumerated() {
        let lines = try recognizeLines(in: imageURL, pass: pass)
        let result = OCRService.parseRecognizedLines(lines)
        firstResult = firstResult ?? (result, lines, index)
        if OCRService.isReliableRecognitionResult(result) {
            return (result, lines, index)
        }
    }
    guard let firstResult else {
        throw NSError(domain: "OCRImageIntegrationRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: "No OCR result"])
    }
    return firstResult
}

@main
enum OCRImageIntegrationRunner {
    static func main() {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: OCRImageIntegrationRunner <receipt-directory>\n", stderr)
            exit(64)
        }

        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let extensions: Set<String> = ["jpg", "jpeg", "png", "webp"]
        let fileManager = FileManager.default
        let files: [(relativePath: String, url: URL)]
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            files = [(root.lastPathComponent, root)]
        } else {
            files = ((try? fileManager.subpathsOfDirectory(atPath: root.path))?
                .filter {
                    let path = URL(fileURLWithPath: $0)
                    return !path.pathComponents.contains("_sources") &&
                        extensions.contains(path.pathExtension.lowercased())
                }
                .sorted() ?? [])
                .map { ($0, root.appendingPathComponent($0)) }
        }

        for file in files {
            do {
                let (result, lines, pass) = try bestResult(for: file.url)
                let currency = result.currencyCode ?? ""
                let reviewKeys = result.lowConfidenceFieldKeys.sorted().joined(separator: ",")
                print("FILE\t\(file.relativePath)")
                print("RESULT\tpass=\(pass + 1)\ttotal=\(result.totalText)\ttax=\(result.taxText)\tsubtotal=\(result.subtotalText)\tcurrency=\(currency)\treview=\(reviewKeys)")
                for line in lines {
                    print("TEXT\t\(line.text.replacingOccurrences(of: "\n", with: " "))")
                }
                print("END")
            } catch {
                print("FILE\t\(file.relativePath)")
                print("ERROR\t\(error.localizedDescription)")
                print("END")
            }
        }
    }
}

import Foundation
import PDFKit
import UIKit

enum ExportService {
    static func exportPDF(receipts: [Receipt], reportTitle: String = "Receipt Vault Report", dateRangeLabel: String? = nil, imageURL: (String) -> URL, to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            var y: CGFloat = 42
            let currencyCode = receipts.first?.currencyCode ?? CurrencyOption.defaultCode
            let totalAmount = receipts.reduce(Decimal.zero) { $0 + $1.total }
            let taxTotal = receipts.reduce(Decimal.zero) { $0 + ($1.tax ?? 0) }

            func draw(_ text: String, font: UIFont, color: UIColor = .label, x: CGFloat = 42) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
                y += font.lineHeight + 8
            }

            draw(reportTitle, font: .boldSystemFont(ofSize: 28))
            draw("Offline private receipt export", font: .systemFont(ofSize: 13), color: .secondaryLabel)
            draw("Generated \(Date().formatted(date: .abbreviated, time: .shortened))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            if let dateRangeLabel {
                draw("Date range: \(dateRangeLabel)", font: .boldSystemFont(ofSize: 13))
            }
            y += 16

            draw("Summary", font: .boldSystemFont(ofSize: 18))
            draw("Receipts: \(receipts.count)", font: .systemFont(ofSize: 13), color: .secondaryLabel)
            draw("Total amount: \(totalAmount.formatted(.currency(code: currencyCode)))", font: .boldSystemFont(ofSize: 14))
            draw("Total tax: \(taxTotal.formatted(.currency(code: currencyCode)))", font: .boldSystemFont(ofSize: 14))
            y += 14

            draw("Category Summary", font: .boldSystemFont(ofSize: 15))
            for category in ReceiptCategory.allCases {
                let categoryReceipts = receipts.filter { $0.category == category }
                let total = categoryReceipts.reduce(Decimal.zero) { $0 + $1.total }
                guard total > 0 else { continue }
                draw("\(category.localizedName): \(total.formatted(.currency(code: currencyCode)))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            }
            y += 10

            draw("Project / Client Summary", font: .boldSystemFont(ofSize: 15))
            let projectGroups = Dictionary(grouping: receipts) { receipt in
                receipt.project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unassigned" : receipt.project
            }
            for group in projectGroups.map({ (name: $0.key, total: $0.value.reduce(Decimal.zero) { $0 + $1.total }) }).sorted(by: { $0.total > $1.total }) {
                draw("\(group.name): \(group.total.formatted(.currency(code: currencyCode)))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            }
            y += 10

            draw("Original Image Attachments", font: .boldSystemFont(ofSize: 15))
            let attachmentNames = receipts.compactMap(\.imageFileName)
            if attachmentNames.isEmpty {
                draw("No original receipt images attached.", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            } else {
                for name in attachmentNames.prefix(12) {
                    draw("images/\(name)", font: .systemFont(ofSize: 9), color: .secondaryLabel)
                }
                if attachmentNames.count > 12 {
                    draw("+ \(attachmentNames.count - 12) more image files in ZIP package", font: .systemFont(ofSize: 9), color: .secondaryLabel)
                }
            }

            context.beginPage()
            y = 42
            draw("Receipt Detail", font: .boldSystemFont(ofSize: 20))

            for receipt in receipts.sorted(by: { $0.date > $1.date }) {
                if y > 710 {
                    context.beginPage()
                    y = 42
                }
                draw(receipt.merchant, font: .boldSystemFont(ofSize: 15))
                draw("\(receipt.date.formatted(date: .abbreviated, time: .omitted))  \(receipt.category.localizedName)  \(receipt.total.formatted(.currency(code: receipt.currencyCode)))", font: .systemFont(ofSize: 12), color: .secondaryLabel)
                var details: [String] = []
                if let subtotal = receipt.subtotal { details.append("Subtotal \(subtotal)") }
                if let tax = receipt.tax { details.append("Tax \(tax)") }
                if let taxRate = receipt.taxRate { details.append("Tax rate \(taxRate)%") }
                if let tip = receipt.tip { details.append("Tip \(tip)") }
                if !receipt.paymentMethod.isEmpty { details.append(receipt.paymentMethod) }
                if !receipt.cardLast4.isEmpty { details.append("•••• \(receipt.cardLast4)") }
                if !details.isEmpty {
                    draw(details.joined(separator: "  "), font: .systemFont(ofSize: 10), color: .secondaryLabel)
                }
                if !receipt.project.isEmpty {
                    draw("Project: \(receipt.project)", font: .systemFont(ofSize: 11), color: .secondaryLabel)
                }
                if !receipt.storeAddress.isEmpty {
                    draw(receipt.storeAddress, font: .systemFont(ofSize: 10), color: .secondaryLabel)
                }
                if !receipt.lineItems.isEmpty {
                    draw("Items: " + receipt.lineItems.prefix(3).map(\.name).joined(separator: ", "), font: .systemFont(ofSize: 10), color: .secondaryLabel)
                }
                if let fileName = receipt.imageFileName,
                   let image = UIImage(contentsOfFile: imageURL(fileName).path) {
                    let target = CGRect(x: 430, y: y - 58, width: 120, height: 80)
                    image.draw(in: target)
                }
                y += 12
                let line = UIBezierPath()
                line.move(to: CGPoint(x: 42, y: y))
                line.addLine(to: CGPoint(x: 570, y: y))
                UIColor.separator.setStroke()
                line.lineWidth = 1
                line.stroke()
                y += 16
            }
        }
    }

    static func exportZIP(files: [URL], to destination: URL) throws -> URL {
        let archiveURL = destination.deletingPathExtension().appendingPathExtension("zip")
        try? FileManager.default.removeItem(at: archiveURL)
        try ZipWriter.zipDirectory(destination, to: archiveURL)
        return archiveURL
    }
}

private enum ZipWriter {
    struct CentralDirectoryEntry {
        let fileName: String
        let crc32: UInt32
        let size: UInt32
        let offset: UInt32
    }

    static func zipDirectory(_ directoryURL: URL, to archiveURL: URL) throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            throw NSError(domain: "ZipWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read export folder."])
        }

        var archive = Data()
        var centralEntries: [CentralDirectoryEntry] = []

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let fileData = try Data(contentsOf: fileURL)
            let relativeName = fileURL.path
                .replacingOccurrences(of: directoryURL.path + "/", with: "")
                .replacingOccurrences(of: " ", with: "_")
            let nameData = Data(relativeName.utf8)
            let crc = CRC32.checksum(fileData)
            let size = UInt32(fileData.count)
            let offset = UInt32(archive.count)

            appendUInt32(0x04034b50, to: &archive)
            appendUInt16(20, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt32(crc, to: &archive)
            appendUInt32(size, to: &archive)
            appendUInt32(size, to: &archive)
            appendUInt16(UInt16(nameData.count), to: &archive)
            appendUInt16(0, to: &archive)
            archive.append(nameData)
            archive.append(fileData)

            centralEntries.append(CentralDirectoryEntry(fileName: relativeName, crc32: crc, size: size, offset: offset))
        }

        let centralDirectoryOffset = UInt32(archive.count)
        for entry in centralEntries {
            let nameData = Data(entry.fileName.utf8)
            appendUInt32(0x02014b50, to: &archive)
            appendUInt16(20, to: &archive)
            appendUInt16(20, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt32(entry.crc32, to: &archive)
            appendUInt32(entry.size, to: &archive)
            appendUInt32(entry.size, to: &archive)
            appendUInt16(UInt16(nameData.count), to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt32(0, to: &archive)
            appendUInt32(entry.offset, to: &archive)
            archive.append(nameData)
        }

        let centralDirectorySize = UInt32(archive.count) - centralDirectoryOffset
        appendUInt32(0x06054b50, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(UInt16(centralEntries.count), to: &archive)
        appendUInt16(UInt16(centralEntries.count), to: &archive)
        appendUInt32(centralDirectorySize, to: &archive)
        appendUInt32(centralDirectoryOffset, to: &archive)
        appendUInt16(0, to: &archive)

        try archive.write(to: archiveURL, options: [.atomic])
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var littleEndian = value.littleEndian
        data.append(Data(bytes: &littleEndian, count: MemoryLayout<UInt16>.size))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var littleEndian = value.littleEndian
        data.append(Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size))
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xffffffff
    }

    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = 0xedb88320 ^ (crc >> 1)
            } else {
                crc >>= 1
            }
        }
        return crc
    }
}

import Foundation
import UIKit

@MainActor
final class ReceiptStore: ObservableObject {
    @Published private(set) var receipts: [Receipt] = []
    @Published private(set) var expenseReports: [ExpenseReport] = []

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    var totalAmount: Decimal {
        receipts.reduce(Decimal.zero) { $0 + $1.total }
    }

    var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var imagesURL: URL {
        documentsURL.appendingPathComponent("ReceiptImages", isDirectory: true)
    }

    var exportsURL: URL {
        documentsURL.appendingPathComponent("Exports", isDirectory: true)
    }

    @discardableResult
    func add(from draft: ReceiptDraft) -> Receipt {
        var fileName = draft.imageFileName
        if let data = draft.imageData {
            fileName = saveImageData(data)
        }

        let receipt = Receipt(
            merchant: draft.merchant.isEmpty ? "Unknown merchant" : draft.merchant,
            date: draft.date,
            subtotal: draft.subtotal,
            total: draft.total,
            tax: draft.tax,
            taxRate: draft.taxRate,
            tip: draft.tip,
            currencyCode: draft.currencyCode.isEmpty ? "USD" : draft.currencyCode.uppercased(),
            category: draft.category,
            paymentMethod: draft.paymentMethod,
            cardLast4: draft.cardLast4,
            transactionID: draft.transactionID,
            storeAddress: draft.storeAddress,
            receiptNumber: draft.receiptNumber,
            lineItems: draft.lineItems,
            project: draft.project,
            notes: draft.notes,
            recognizedText: draft.recognizedText,
            imageFileName: fileName
        )
        receipts.insert(receipt, at: 0)
        save()
        return receipt
    }

    func update(_ receipt: Receipt) {
        guard let index = receipts.firstIndex(where: { $0.id == receipt.id }) else { return }
        var updated = receipt
        updated.updatedAt = .now
        receipts[index] = updated
        sort()
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            if let fileName = receipts[index].imageFileName {
                try? fileManager.removeItem(at: imageURL(for: fileName))
            }
        }
        receipts.remove(atOffsets: offsets)
        expenseReports = expenseReports.map { report in
            var updated = report
            updated.receiptIDs.removeAll { id in !receipts.contains(where: { $0.id == id }) }
            return updated
        }
        save()
    }

    func delete(_ receipt: Receipt) {
        guard let index = receipts.firstIndex(where: { $0.id == receipt.id }) else { return }
        delete(at: IndexSet(integer: index))
    }

    func imageURL(for fileName: String) -> URL {
        imagesURL.appendingPathComponent(fileName)
    }

    func exportCSV(receipts exportReceipts: [Receipt]? = nil) throws -> URL {
        let receiptsToExport = exportReceipts ?? receipts
        try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        let url = exportsURL.appendingPathComponent("ReceiptVault-\(dateRangeSlug(for: receiptsToExport)).csv")
        try csvData(for: receiptsToExport).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportPDF(receipts exportReceipts: [Receipt]? = nil) throws -> URL {
        let receiptsToExport = exportReceipts ?? receipts
        try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        let rangeSlug = dateRangeSlug(for: receiptsToExport)
        let url = exportsURL.appendingPathComponent("ReceiptVault-\(rangeSlug).pdf")
        try ExportService.exportPDF(
            receipts: receiptsToExport,
            dateRangeLabel: dateRangeLabel(for: receiptsToExport),
            imageURL: imageURL(for:),
            to: url
        )
        return url
    }

    func exportZIP(receipts exportReceipts: [Receipt]? = nil) throws -> URL {
        let receiptsToExport = exportReceipts ?? receipts
        try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        let rangeSlug = dateRangeSlug(for: receiptsToExport)
        let packageURL = exportsURL.appendingPathComponent("ReceiptVault-\(rangeSlug)", isDirectory: true)
        try? fileManager.removeItem(at: packageURL)
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)

        try csvData(for: receiptsToExport).write(to: packageURL.appendingPathComponent("receipts-\(rangeSlug).csv"), atomically: true, encoding: .utf8)
        try ExportService.exportPDF(
            receipts: receiptsToExport,
            dateRangeLabel: dateRangeLabel(for: receiptsToExport),
            imageURL: imageURL(for:),
            to: packageURL.appendingPathComponent("receipt-report-\(rangeSlug).pdf")
        )

        let imageFolder = packageURL.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: imageFolder, withIntermediateDirectories: true)
        for receipt in receiptsToExport {
            guard let fileName = receipt.imageFileName else { continue }
            let source = imageURL(for: fileName)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let safeMerchant = receipt.merchant
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            let destination = imageFolder.appendingPathComponent("\(receipt.date.formatted(.iso8601.year().month().day()))-\(safeMerchant)-\(fileName)")
            try? fileManager.copyItem(at: source, to: destination)
        }

        return try ExportService.exportZIP(files: [], to: packageURL)
    }

    func addExpenseReport(_ draft: ExpenseReportDraft) {
        let report = ExpenseReport(
            title: draft.title.isEmpty ? "Expense Report" : draft.title,
            companyName: draft.companyName,
            claimantName: draft.claimantName,
            department: draft.department,
            startDate: draft.startDate,
            endDate: draft.endDate,
            status: draft.status,
            receiptIDs: draft.receiptIDs,
            notes: draft.notes
        )
        expenseReports.insert(report, at: 0)
        save()
    }

    func updateExpenseReport(_ report: ExpenseReport) {
        guard let index = expenseReports.firstIndex(where: { $0.id == report.id }) else { return }
        var updated = report
        updated.updatedAt = .now
        expenseReports[index] = updated
        save()
    }

    func deleteExpenseReport(_ report: ExpenseReport) {
        expenseReports.removeAll { $0.id == report.id }
        save()
    }

    func receipts(for report: ExpenseReport) -> [Receipt] {
        receipts.filter { report.receiptIDs.contains($0.id) }.sorted { $0.date > $1.date }
    }

    func exportBackup(to url: URL) throws {
        let backup = ReceiptVaultBackup(receipts: receipts, expenseReports: expenseReports, images: backupImages())
        let data = try encoder.encode(backup)
        try data.write(to: url, options: [.atomic])
    }

    func exportBackup(to url: URL, password: String?) throws {
        let backup = ReceiptVaultBackup(receipts: receipts, expenseReports: expenseReports, images: backupImages())
        let data = try encoder.encode(backup)
        let output: Data
        if let password, !password.isEmpty {
            output = try BackupCrypto.encrypt(data, password: password)
        } else {
            output = data
        }
        try output.write(to: url, options: [.atomic])
    }

    func importBackup(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let backup = try decoder.decode(ReceiptVaultBackup.self, from: data)
        receipts = backup.receipts.sorted { $0.date > $1.date }
        expenseReports = backup.expenseReports.sorted { $0.createdAt > $1.createdAt }
        try restoreImages(backup.images)
        save()
    }

    func importBackup(from url: URL, password: String?) throws {
        let data = try Data(contentsOf: url)
        let decoded: Data
        if let password, !password.isEmpty {
            decoded = try BackupCrypto.decrypt(data, password: password)
        } else {
            decoded = data
        }
        let backup = try decoder.decode(ReceiptVaultBackup.self, from: decoded)
        receipts = backup.receipts.sorted { $0.date > $1.date }
        expenseReports = backup.expenseReports.sorted { $0.createdAt > $1.createdAt }
        try restoreImages(backup.images)
        save()
    }

    func clearAllData() {
        receipts.removeAll()
        expenseReports.removeAll()
        try? fileManager.removeItem(at: imagesURL)
        try? fileManager.removeItem(at: exportsURL)
        save()
    }

    func duplicateCandidates(for draft: ReceiptDraft) -> [Receipt] {
        receipts.filter { receipt in
            let sameAmount = receipt.total == draft.total
            let sameDate = Calendar.current.isDate(receipt.date, inSameDayAs: draft.date)
            let normalizedMerchant = receipt.merchant.normalizedForMatching
            let draftMerchant = draft.merchant.normalizedForMatching
            let sameMerchant = !normalizedMerchant.isEmpty && !draftMerchant.isEmpty && (normalizedMerchant.contains(draftMerchant) || draftMerchant.contains(normalizedMerchant))
            return sameAmount && sameDate && (sameMerchant || draftMerchant.isEmpty)
        }
    }

    func filteredReceipts(query: String, category: ReceiptCategory?, dateFilter: ReceiptDateFilter) -> [Receipt] {
        receipts.filter { receipt in
            let matchesQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || receipt.searchableText.localizedCaseInsensitiveContains(query)
            let matchesCategory = category == nil || receipt.category == category
            let matchesDate: Bool
            switch dateFilter {
            case .all:
                matchesDate = true
            case .thisMonth:
                matchesDate = Calendar.current.isDate(receipt.date, equalTo: .now, toGranularity: .month)
            case .thisYear:
                matchesDate = Calendar.current.isDate(receipt.date, equalTo: .now, toGranularity: .year)
            }
            return matchesQuery && matchesCategory && matchesDate
        }
    }

    private func csvData(for receipts: [Receipt]) -> String {
        let rows = receipts.map { receipt in
            [
                receipt.date.formatted(.iso8601.year().month().day()),
                receipt.merchant,
                receipt.subtotal.map { "\($0)" } ?? "",
                "\(receipt.total)",
                receipt.tax.map { "\($0)" } ?? "",
                receipt.taxRate.map { "\($0)" } ?? "",
                receipt.tip.map { "\($0)" } ?? "",
                receipt.currencyCode,
                receipt.category.localizedName,
                receipt.paymentMethod,
                receipt.cardLast4,
                receipt.transactionID,
                receipt.receiptNumber,
                receipt.storeAddress,
                receipt.project,
                receipt.notes
            ].map(Self.csvEscape).joined(separator: ",")
        }

        let header = "Date,Merchant,Subtotal,Total,Tax,Tax Rate,Tip,Currency,Category,Payment Method,Card Last 4,Transaction ID,Receipt Number,Store Address,Project,Notes"
        return ([header] + rows).joined(separator: "\n")
    }

    private func load() {
        do {
            try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            let data = try Data(contentsOf: dataURL)
            if let backup = try? decoder.decode(ReceiptVaultBackup.self, from: data) {
                receipts = backup.receipts
                expenseReports = backup.expenseReports
            } else {
                receipts = try decoder.decode([Receipt].self, from: data)
                expenseReports = []
            }
            sort()
        } catch {
            receipts = []
            expenseReports = []
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            let data = try encoder.encode(ReceiptVaultBackup(receipts: receipts, expenseReports: expenseReports))
            try data.write(to: dataURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save receipts: \(error.localizedDescription)")
        }
    }

    private func saveImageData(_ data: Data) -> String? {
        do {
            try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).jpg"
            try data.write(to: imageURL(for: fileName), options: [.atomic])
            return fileName
        } catch {
            return nil
        }
    }

    private func backupImages() -> [String: Data] {
        receipts.reduce(into: [:]) { result, receipt in
            guard let fileName = receipt.imageFileName else { return }
            let url = imageURL(for: fileName)
            guard let data = try? Data(contentsOf: url) else { return }
            result[fileName] = data
        }
    }

    private func restoreImages(_ images: [String: Data]) throws {
        try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        for (fileName, data) in images {
            try data.write(to: imageURL(for: fileName), options: [.atomic])
        }
    }

    private func sort() {
        receipts.sort { $0.date > $1.date }
        expenseReports.sort { $0.createdAt > $1.createdAt }
    }

    private var dataURL: URL {
        documentsURL.appendingPathComponent("receipts.json")
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private func dateRangeSlug(for receipts: [Receipt]) -> String {
        guard let oldest = receipts.map(\.date).min(),
              let newest = receipts.map(\.date).max() else {
            return Date().formatted(.iso8601.year().month().day())
        }
        let start = oldest.formatted(.iso8601.year().month().day())
        let end = newest.formatted(.iso8601.year().month().day())
        return start == end ? start : "\(start)-to-\(end)"
    }

    private func dateRangeLabel(for receipts: [Receipt]) -> String {
        guard let oldest = receipts.map(\.date).min(),
              let newest = receipts.map(\.date).max() else {
            return "No receipts"
        }
        return "\(oldest.formatted(date: .abbreviated, time: .omitted)) - \(newest.formatted(date: .abbreviated, time: .omitted))"
    }
}

private extension Receipt {
    var searchableText: String {
        [merchant, currencyCode, category.rawValue, project, notes, recognizedText].joined(separator: " ")
    }
}

private extension String {
    var normalizedForMatching: String {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}

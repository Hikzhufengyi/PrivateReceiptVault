import Foundation
import UIKit
import Vision

struct OCRResult {
    var text: String
    var merchant: String
    var subtotalText: String
    var totalText: String
    var taxText: String
    var taxRateText: String
    var tipText: String
    var date: Date?
    var paymentMethod: String
    var cardLast4: String
    var transactionID: String
    var storeAddress: String
    var receiptNumber: String
    var lineItems: [ReceiptLineItem]
    var currencyCode: String?
    var recognizedFieldKeys: Set<String>
    var lowConfidenceFieldKeys: Set<String>
}

enum OCRService {
    static func recognize(image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read image."])
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "zh-Hans"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
        try handler.perform([request])

        let lines = request.results?
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        let text = lines.joined(separator: "\n")
        let subtotalText = amountForKeywords(["subtotal", "sub total", "sub-total", "sub ttl", "subttl", "sub tot", "net total", "amount"], from: lines) ?? ""
        let totalText = guessTotal(from: lines)
        let taxText = guessTax(from: lines)
        let taxRateText = guessTaxRate(from: lines)
        let tipText = amountForKeywords(["tip", "gratuity", "service charge", "svc chg"], from: lines) ?? ""
        let date = guessDate(from: lines)
        let merchant = guessMerchant(from: lines)
        let paymentMethod = guessPaymentMethod(from: lines)
        let cardLast4 = guessCardLast4(from: lines)
        let transactionID = guessTransactionID(from: lines)
        let storeAddress = guessStoreAddress(from: lines)
        let receiptNumber = guessReceiptNumber(from: lines)
        let lineItems = guessLineItems(from: lines)
        let recognizedFieldKeys = recognizedKeys(
            merchant: merchant,
            date: date,
            subtotalText: subtotalText,
            totalText: totalText,
            taxText: taxText,
            taxRateText: taxRateText,
            tipText: tipText,
            paymentMethod: paymentMethod,
            cardLast4: cardLast4,
            transactionID: transactionID,
            storeAddress: storeAddress,
            receiptNumber: receiptNumber,
            lineItems: lineItems
        )
        return OCRResult(
            text: text,
            merchant: merchant,
            subtotalText: subtotalText,
            totalText: totalText,
            taxText: taxText,
            taxRateText: taxRateText,
            tipText: tipText,
            date: date,
            paymentMethod: paymentMethod,
            cardLast4: cardLast4,
            transactionID: transactionID,
            storeAddress: storeAddress,
            receiptNumber: receiptNumber,
            lineItems: lineItems,
            currencyCode: guessCurrencyCode(from: text),
            recognizedFieldKeys: recognizedFieldKeys,
            lowConfidenceFieldKeys: lowConfidenceKeys(recognizedKeys: recognizedFieldKeys, text: text)
        )
    }

    private static func guessMerchant(from lines: [String]) -> String {
        lines.prefix(10)
            .filter(isMerchantCandidate)
            .sorted { merchantScore($0) > merchantScore($1) }
            .first ?? ""
    }

    private static func guessTotal(from lines: [String]) -> String {
        let totalKeywords = ["grand total", "amount due", "balance due", "total due", "total", "balance", "sum", "paid"]
        return amountForKeywords(totalKeywords, from: lines) ?? amount(in: lines.reversed().first(where: \.containsAmount) ?? "") ?? ""
    }

    private static func guessTax(from lines: [String]) -> String {
        amountForKeywords(["sales tax", "tax total", "tax amount", "tax", "vat", "gst", "hst", "pst", "state tax", "city tax", "tx"], from: lines) ?? ""
    }

    private static func guessTaxRate(from lines: [String]) -> String {
        let taxLines = lines.filter { line in
            let lower = line.lowercased()
            return lower.contains("tax") || lower.contains("vat")
        }
        let pattern = #"(?<!\d)(\d{1,2}(?:[.]\d{1,3})?)\s*%"#
        return taxLines.compactMap {
            firstMatch(pattern: pattern, in: $0, options: [.caseInsensitive])
        }.first ?? ""
    }

    private static func amountForKeywords(_ keywords: [String], from lines: [String]) -> String? {
        let candidates = lines.filter { line in
            let lower = line.lowercased()
            return keywords.contains { lower.contains($0) }
        }
        return candidates.compactMap(amount(in:)).last
    }

    private static func guessDate(from lines: [String]) -> Date? {
        let patterns = [
            #"(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?!\d)"#,
            #"(?<!\d)(\d{1,2})[.](\d{1,2})[.](\d{2,4})(?!\d)"#,
            #"(?<!\d)(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?!\d)"#,
            #"(?<!\d)(\d{4})[.](\d{1,2})[.](\d{1,2})(?!\d)"#,
            #"(?i)\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*[ .,/-]+(\d{1,2})[a-z]{0,2}[, ]+(\d{2,4})\b"#,
            #"(?i)\b(\d{1,2})[ .,/-]+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*[ .,/-]+(\d{2,4})\b"#
        ]
        let calendar = Calendar.current

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { continue }
                var components = DateComponents()
                if pattern.contains("jan|feb") {
                    guard let firstRange = Range(match.range(at: 1), in: line),
                          let secondRange = Range(match.range(at: 2), in: line),
                          let thirdRange = Range(match.range(at: 3), in: line) else { continue }
                    let first = String(line[firstRange])
                    let second = String(line[secondRange])
                    let third = String(line[thirdRange])
                    if let month = monthNumber(from: first), let day = Int(second), let year = Int(third) {
                        components.month = month
                        components.day = day
                        components.year = normalizedYear(year)
                    } else if let day = Int(first), let month = monthNumber(from: second), let year = Int(third) {
                        components.month = month
                        components.day = day
                        components.year = normalizedYear(year)
                    }
                } else {
                    let groups = (1..<match.numberOfRanges).compactMap { index -> Int? in
                        guard let range = Range(match.range(at: index), in: line) else { return nil }
                        return Int(line[range])
                    }
                    if pattern.hasPrefix("(?<!\\d)(\\d{4})"), groups.count == 3 {
                        components.year = groups[0]
                        components.month = groups[1]
                        components.day = groups[2]
                    } else if groups.count == 3 {
                        components.month = groups[0]
                        components.day = groups[1]
                        components.year = normalizedYear(groups[2])
                    }
                }
                if let date = calendar.date(from: components) {
                    return date
                }
            }
        }
        return nil
    }

    private static func amount(in line: String) -> String? {
        let pattern = #"(?<!\d)(?:[$€£¥]\s*)?(\d{1,6}(?:[,.]\d{3})*(?:[.]\d{2})|\d+[.]\d{2})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).last,
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range]).replacingOccurrences(of: ",", with: "")
    }

    private static func isMerchantCandidate(_ line: String) -> Bool {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()
        guard cleaned.count >= 2 else { return false }
        guard !cleaned.containsAmount else { return false }
        guard !cleaned.isMostlyPunctuation else { return false }
        guard lower.range(of: #"\d{3}[-. ]?\d{3}[-. ]?\d{4}"#, options: .regularExpression) == nil else { return false }
        guard lower.range(of: #"\d{1,6}\s+[a-z0-9 .'-]+(?:st|street|ave|avenue|rd|road|blvd|drive|dr|lane|ln)\b"#, options: .regularExpression) == nil else { return false }
        let blocked = ["receipt", "invoice", "check", "table", "server", "cashier", "terminal", "merchant id", "store #", "order", "auth", "approval", "visa", "mastercard", "thank you", "duplicate"]
        return !blocked.contains { lower.contains($0) }
    }

    private static func merchantScore(_ line: String) -> Int {
        let letters = line.filter(\.isLetter).count
        let uppercase = line.filter { $0.isLetter && $0.isUppercase }.count
        let digits = line.filter(\.isNumber).count
        var score = letters * 2 - digits
        if letters > 0, uppercase * 2 >= letters { score += 8 }
        if line.count <= 28 { score += 4 }
        return score
    }

    private static func normalizedYear(_ year: Int) -> Int {
        year < 100 ? 2000 + year : year
    }

    private static func monthNumber(from text: String) -> Int? {
        switch text.lowercased().prefix(3) {
        case "jan": 1
        case "feb": 2
        case "mar": 3
        case "apr": 4
        case "may": 5
        case "jun": 6
        case "jul": 7
        case "aug": 8
        case "sep": 9
        case "oct": 10
        case "nov": 11
        case "dec": 12
        default: nil
        }
    }

    private static func guessPaymentMethod(from lines: [String]) -> String {
        let lowered = lines.map { $0.lowercased() }
        if lowered.contains(where: { $0.contains("visa") }) { return "Visa" }
        if lowered.contains(where: { $0.contains("mastercard") || $0.contains("master card") }) { return "Mastercard" }
        if lowered.contains(where: { $0.contains("amex") || $0.contains("american express") }) { return "American Express" }
        if lowered.contains(where: { $0.contains("discover") }) { return "Discover" }
        if lowered.contains(where: { $0.contains("cash") }) { return "Cash" }
        if lowered.contains(where: { $0.contains("apple pay") }) { return "Apple Pay" }
        return ""
    }

    private static func guessCardLast4(from lines: [String]) -> String {
        let pattern = #"(?:\*{2,}|x{2,}|ending|last\s*4|card)[^\d]*(\d{4})(?!\d)"#
        return firstMatch(pattern: pattern, in: lines.joined(separator: " "), options: [.caseInsensitive]) ?? ""
    }

    private static func guessTransactionID(from lines: [String]) -> String {
        let pattern = #"(?:transaction|trans|txn|auth|approval|ref)[\s#:.-]*([A-Z0-9-]{4,})"#
        return firstMatch(pattern: pattern, in: lines.joined(separator: " "), options: [.caseInsensitive]) ?? ""
    }

    private static func guessReceiptNumber(from lines: [String]) -> String {
        let pattern = #"(?:receipt|check|order|invoice)[\s#:.-]*([A-Z0-9-]{3,})"#
        return firstMatch(pattern: pattern, in: lines.joined(separator: " "), options: [.caseInsensitive]) ?? ""
    }

    private static func guessStoreAddress(from lines: [String]) -> String {
        lines.first { line in
            line.range(of: #"\d{1,6}\s+[A-Za-z0-9 .'-]+(?:st|street|ave|avenue|rd|road|blvd|drive|dr|lane|ln)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        } ?? ""
    }

    private static func guessLineItems(from lines: [String]) -> [ReceiptLineItem] {
        let skipKeywords = ["subtotal", "total", "tax", "tip", "balance", "visa", "mastercard", "cash", "change", "amount due"]
        return lines.compactMap { line in
            let lower = line.lowercased()
            guard line.containsAmount, !skipKeywords.contains(where: { lower.contains($0) }), let value = amount(in: line) else {
                return nil
            }
            let name = line.replacingOccurrences(of: #"(?:[$€£¥]\s*)?\d{1,6}(?:[,.]\d{3})*(?:[.]\d{2})|\d+[.]\d{2}"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return ReceiptLineItem(name: name, quantity: nil, amount: DecimalParser.parse(value))
        }
    }

    private static func guessCurrencyCode(from text: String) -> String? {
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("¥") || text.contains("￥") {
            let lower = text.lowercased()
            if lower.contains("jpy") || lower.contains("japan") || lower.contains("yen") {
                return "JPY"
            }
            return "CNY"
        }
        if text.contains("HK$") { return "HKD" }
        if text.contains("S$") { return "SGD" }
        if text.contains("C$") { return "CAD" }
        if text.contains("A$") { return "AUD" }
        if text.contains("$") { return "USD" }
        if text.range(of: #"\d+[.]\d{2}"#, options: .regularExpression) != nil {
            return "USD"
        }
        return nil
    }

    private static func recognizedKeys(
        merchant: String,
        date: Date?,
        subtotalText: String,
        totalText: String,
        taxText: String,
        taxRateText: String,
        tipText: String,
        paymentMethod: String,
        cardLast4: String,
        transactionID: String,
        storeAddress: String,
        receiptNumber: String,
        lineItems: [ReceiptLineItem]
    ) -> Set<String> {
        var keys: Set<String> = []
        if !merchant.isEmpty { keys.insert("merchant") }
        if date != nil { keys.insert("date") }
        if !subtotalText.isEmpty { keys.insert("subtotal") }
        if !totalText.isEmpty { keys.insert("total") }
        if !taxText.isEmpty { keys.insert("tax") }
        if !taxRateText.isEmpty { keys.insert("taxRate") }
        if !tipText.isEmpty { keys.insert("tip") }
        if !paymentMethod.isEmpty { keys.insert("paymentMethod") }
        if !cardLast4.isEmpty { keys.insert("cardLast4") }
        if !transactionID.isEmpty { keys.insert("transactionID") }
        if !storeAddress.isEmpty { keys.insert("storeAddress") }
        if !receiptNumber.isEmpty { keys.insert("receiptNumber") }
        if !lineItems.isEmpty { keys.insert("lineItems") }
        return keys
    }

    private static func lowConfidenceKeys(recognizedKeys: Set<String>, text: String) -> Set<String> {
        var keys: Set<String> = []
        if !recognizedKeys.contains("total") { keys.insert("total") }
        if !recognizedKeys.contains("date") { keys.insert("date") }
        if !recognizedKeys.contains("merchant") { keys.insert("merchant") }
        if text.count < 40 {
            keys.formUnion(["merchant", "date", "total", "tax"])
        }
        return keys
    }

    private static func firstMatch(pattern: String, in text: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

private extension String {
    var containsAmount: Bool {
        self.range(of: #"\d+[.]\d{2}"#, options: .regularExpression) != nil
    }

    var isMostlyPunctuation: Bool {
        let meaningful = filter { $0.isLetter || $0.isNumber }.count
        return meaningful * 2 < count
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

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
    var category: ReceiptCategory?
    var recognizedFieldKeys: Set<String>
    var lowConfidenceFieldKeys: Set<String>
}

enum OCRService {
    static func recognize(image: UIImage) async throws -> OCRResult {
        try await recognize(images: [image])
    }

    static func recognize(images: [UIImage]) async throws -> OCRResult {
        var candidates: [OCRResult] = []
        var lastError: Error?

        for (index, image) in images.enumerated() {
            do {
                candidates.append(contentsOf: try recognizeCandidates(image: image, imageIndex: index))
            } catch {
                lastError = error
            }
        }

        if let best = candidates.max(by: { resultScore($0) < resultScore($1) }) {
            debugPrintSelectedResult(best)
            return best
        }

        if let lastError {
            throw lastError
        }

        return parsedResult(from: [])
    }

    private static func recognizeCandidates(image: UIImage, imageIndex: Int) throws -> [OCRResult] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read image."])
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try recognitionLanguageGroups.map { languages in
            let lines = try recognizedLines(cgImage: cgImage, orientation: orientation, languages: languages)
            debugPrintRecognizedLines(imageIndex: imageIndex, imageSize: image.size, languages: languages, lines: lines)
            return parsedResult(from: lines)
        }
    }

    private static func debugPrintRecognizedLines(imageIndex: Int, imageSize: CGSize, languages: [String], lines: [String]) {
        let languageList = languages.joined(separator: ",")
        print("[OCR-DEBUG] image=\(imageIndex) size=\(Int(imageSize.width))x\(Int(imageSize.height)) languages=\(languageList) lines=\(lines.count)")
        for (lineIndex, line) in lines.enumerated() {
            print("[OCR-DEBUG] image=\(imageIndex) line=\(lineIndex + 1): \(line)")
        }
    }

    private static func debugPrintSelectedResult(_ result: OCRResult) {
        let merchant = result.merchant.isEmpty ? "<empty>" : result.merchant
        let date = result.date?.description ?? "<empty>"
        let total = result.totalText.isEmpty ? "<empty>" : result.totalText
        let tax = result.taxText.isEmpty ? "<empty>" : result.taxText
        let subtotal = result.subtotalText.isEmpty ? "<empty>" : result.subtotalText
        print("[OCR-DEBUG] selected merchant=\(merchant) date=\(date) total=\(total) tax=\(tax) subtotal=\(subtotal)")
    }

    static func parseRecognizedLines(_ lines: [String]) -> OCRResult {
        parsedResult(from: lines)
    }

    private static let recognitionLanguageGroups: [[String]] = [
        ["zh-Hans", "en-US"],
        ["ja-JP", "en-US"],
        ["ko-KR", "en-US"],
        ["ar-SA", "en-US"],
        ["de-DE", "es-ES", "fr-FR", "it-IT", "nl-NL", "pt-BR", "en-US"]
    ]

    private static func recognizedLines(cgImage: CGImage, orientation: CGImagePropertyOrientation, languages: [String]) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try handler.perform([request])

        return request.results?
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    private static func parsedResult(from lines: [String]) -> OCRResult {
        let text = lines.joined(separator: "\n")
        let subtotalText = stackedSummaryAmount(.subtotal, from: lines) ??
            amountForKeywords(Self.subtotalKeywords, from: lines) ?? ""
        let totalText = guessTotal(from: lines)
        let taxText = guessTax(from: lines)
        let taxRateText = guessTaxRate(from: lines)
        let tipText = stackedSummaryAmount(.tip, from: lines) ??
            amountForKeywords(Self.tipKeywords, from: lines) ?? ""
        let date = guessDate(from: lines)
        let merchant = guessMerchant(from: lines)
        let paymentMethod = guessPaymentMethod(from: lines)
        let cardLast4 = guessCardLast4(from: lines)
        let transactionID = guessTransactionID(from: lines)
        let storeAddress = guessStoreAddress(from: lines)
        let receiptNumber = guessReceiptNumber(from: lines)
        let lineItems = guessLineItems(from: lines)
        let category = guessCategory(merchant: merchant, text: text, lineItems: lineItems)
        let recognizedFieldKeys = recognizedKeys(
            merchant: merchant,
            category: category,
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
            category: category,
            recognizedFieldKeys: recognizedFieldKeys,
            lowConfidenceFieldKeys: lowConfidenceKeys(recognizedKeys: recognizedFieldKeys, text: text)
        )
    }

    private static func resultScore(_ result: OCRResult) -> Int {
        var score = min(result.text.count, 500) / 20
        score += min(result.text.components(separatedBy: .newlines).count, 40)
        if !result.totalText.isEmpty { score += 80 }
        if !result.subtotalText.isEmpty { score += 30 }
        if !result.taxText.isEmpty { score += 30 }
        if containsAnyKeyword(["amount"], in: result.text) { score += 20 }
        if containsAnyKeyword(["balance"], in: result.text) { score += 20 }
        if containsAnyKeyword(["sales tax"], in: result.text) { score += 20 }
        if containsAnyKeyword(["sub-total", "subtotal"], in: result.text) { score += 20 }
        if result.date != nil { score += 45 }
        if !result.merchant.isEmpty { score += 35 }
        if !result.transactionID.isEmpty || !result.receiptNumber.isEmpty { score += 20 }
        if !result.paymentMethod.isEmpty { score += 12 }
        if result.currencyCode?.isEmpty == false { score += 8 }
        if knownChineseMerchant(in: result.text) != nil { score += 70 }
        if isSuspiciousChineseMerchant(result.merchant) { score -= 80 }
        score += result.recognizedFieldKeys.count * 8
        score -= result.text.filter { $0 == "#" || $0 == "�" }.count * 2
        return score
    }

    private static func guessMerchant(from lines: [String]) -> String {
        if let platformMerchant = guessPlatformMerchant(from: lines) {
            return platformMerchant
        }

        let headerLines = lines.prefix { !isMerchantSectionBoundary($0) }
        return headerLines
            .filter(isMerchantCandidate)
            .sorted { merchantScore($0) > merchantScore($1) }
            .first ?? ""
    }

    private static func guessTotal(from lines: [String]) -> String {
        positiveReceiptTotal(
            chineseCommercePaidAmount(from: lines) ??
            stackedSummaryAmount(.total, from: lines) ??
            amountForKeywords(Self.totalKeywords, from: lines, excluding: Self.nonTotalKeywords) ??
            amountAfterStandaloneTotalLabel(from: lines) ??
            largestAmount(from: lines) ?? ""
        )
    }

    private static func guessTax(from lines: [String]) -> String {
        stackedSummaryAmount(.tax, from: lines) ??
            amountForKeywords(Self.taxKeywords, from: lines, excluding: Self.nonAmountTaxKeywords) ?? ""
    }

    private static func positiveReceiptTotal(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("-") || trimmed.hasPrefix("−") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private static func guessTaxRate(from lines: [String]) -> String {
        let taxLines = lines.filter { line in
            containsAnyKeyword(Self.taxKeywords, in: line)
        }
        let pattern = #"(?<!\d)(\d{1,2}(?:[.]\d{1,3})?)\s*%"#
        return taxLines.compactMap {
            firstMatch(pattern: pattern, in: $0, options: [.caseInsensitive])
        }.first ?? ""
    }

    private static func amountForKeywords(_ keywords: [String], from lines: [String], excluding excludedKeywords: [String] = []) -> String? {
        let candidates = lines.enumerated().filter { _, line in
            let isExcluded = excludedKeywords.contains { keyword in
                lineMatchesKeyword(line, keyword)
            }
            return !isExcluded && keywords.contains { keyword in
                lineMatchesKeyword(line, keyword)
            }
        }
        for (index, line) in candidates.reversed() {
            if let value = amount(in: line) {
                return value
            }
            for nearbyLine in lines.dropFirst(index + 1).prefix(4) {
                if containsAnyKeyword(Self.moneyBoundaryKeywords, in: nearbyLine) {
                    break
                }
                if let value = amount(in: nearbyLine) {
                    return value
                }
            }
        }
        return nil
    }

    private enum SummaryField {
        case total
        case subtotal
        case tax
        case tip
        case discount
    }

    private enum ReceiptField {
        case total
        case subtotal
        case tax
        case tip
        case discount
        case payment
    }

    private struct ReceiptFieldToken {
        let field: ReceiptField
        let tokens: [String]
    }

    private static func stackedSummaryAmount(_ field: SummaryField, from lines: [String]) -> String? {
        for block in stackedMoneyLabelBlocks(in: lines).reversed() {
            let trailingAmounts = lines
                .dropFirst(block.endIndex + 1)
                .compactMap(amount(in:))
            guard trailingAmounts.count >= block.labels.count else { continue }

            let summaryAmounts = summaryAmountWindow(for: block.labels, in: trailingAmounts)
            if field == .tax,
               let combinedTaxAmount = combinedAmount(for: .tax, labels: block.labels, amounts: summaryAmounts) {
                return combinedTaxAmount
            }
            for (index, label) in block.labels.enumerated().reversed() where label == field {
                return summaryAmounts[index]
            }
        }
        return nil
    }

    private static func summaryAmountWindow(for labels: [SummaryField], in amounts: [String]) -> [String] {
        guard amounts.count > labels.count else {
            return amounts
        }

        let windows = (0...(amounts.count - labels.count)).map { startIndex in
            Array(amounts[startIndex..<(startIndex + labels.count)])
        }
        if let balancedWindow = windows.max(by: { summaryBalanceScore(labels: labels, amounts: $0) < summaryBalanceScore(labels: labels, amounts: $1) }),
           summaryBalanceScore(labels: labels, amounts: balancedWindow) > 0 {
            return balancedWindow
        }
        return Array(amounts.suffix(labels.count))
    }

    private static func summaryBalanceScore(labels: [SummaryField], amounts: [String]) -> Int {
        guard labels.count == amounts.count,
              let totalIndex = labels.lastIndex(of: .total),
              let total = DecimalParser.parse(amounts[totalIndex]),
              total > Decimal.zero else {
            return 0
        }

        var expectedTotal = Decimal.zero
        var hasComponent = false
        for (index, label) in labels.enumerated() where index != totalIndex {
            guard let amount = DecimalParser.parse(amounts[index]) else { continue }
            switch label {
            case .subtotal, .tax, .tip:
                expectedTotal += amount
                hasComponent = true
            case .discount:
                expectedTotal -= absDecimal(amount)
                hasComponent = true
            case .total:
                break
            }
        }

        guard hasComponent else { return 0 }
        let difference = absDecimal(total - expectedTotal)
        if difference <= Decimal(string: "0.02")! {
            let cents = min(NSDecimalNumber(decimal: total * Decimal(100)).intValue, 90_000)
            return 100 + totalIndex + cents
        }
        return 0
    }

    private static func absDecimal(_ value: Decimal) -> Decimal {
        value < Decimal.zero ? -value : value
    }

    private static func combinedAmount(for field: SummaryField, labels: [SummaryField], amounts: [String]) -> String? {
        let fieldAmounts = labels.enumerated().compactMap { index, label -> Decimal? in
            guard label == field, amounts.indices.contains(index) else { return nil }
            return DecimalParser.parse(amounts[index])
        }
        guard fieldAmounts.count > 1 else { return nil }
        let total = fieldAmounts.reduce(Decimal.zero, +)
        return NSDecimalNumber(decimal: total).stringValue
    }

    private static func stackedMoneyLabelBlocks(in lines: [String]) -> [(labels: [SummaryField], endIndex: Int)] {
        var blocks: [(labels: [SummaryField], endIndex: Int)] = []
        var index = 0

        while index < lines.count {
            var labels: [SummaryField] = []
            var cursor = index

            while cursor < lines.count,
                  !lines[cursor].containsAmount {
                if let label = summaryField(for: lines[cursor]) {
                    labels.append(label)
                } else if labels.isEmpty || !isSummarySpacerLine(lines[cursor]) {
                    break
                }
                cursor += 1
            }

            if labels.count >= 2 {
                blocks.append((labels: labels, endIndex: cursor - 1))
                index = cursor
            } else {
                index += 1
            }
        }

        return blocks
    }

    private static func summaryField(for line: String) -> SummaryField? {
        if containsAnyKeyword(Self.nonSummaryTaxLines, in: line) {
            return nil
        }
        if containsAnyKeyword(Self.taxableBaseKeywords, in: line) {
            return nil
        }
        if containsAnyKeyword(Self.taxKeywords, in: line) {
            return .tax
        }
        if containsAnyKeyword(Self.tipKeywords, in: line) {
            return .tip
        }
        if containsAnyKeyword(Self.discountKeywords, in: line) {
            return .discount
        }
        if containsAnyKeyword(Self.subtotalKeywords, in: line) {
            return .subtotal
        }
        if containsAnyKeyword(Self.totalKeywords + ["amount"], in: line) {
            return .total
        }
        return nil
    }

    private static func isSummarySpacerLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if containsAnyKeyword(Self.taxableBaseKeywords, in: line) {
            return true
        }
        if trimmed.range(of: #"^[（(]?\s*\d{1,2}(?:[.]\d{1,3})?\s*%[）)]?$"#, options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: #"^\d+\s*(点|件|品|item|items)$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return false
    }

    private static func amountAfterStandaloneTotalLabel(from lines: [String]) -> String? {
        let labels = ["amount", "total", "balance"]
        for (index, line) in lines.enumerated().reversed() {
            guard labels.contains(where: { lineMatchesKeyword(line, $0) }) else { continue }
            let nearbyLines = lines.dropFirst(index + 1).prefix(4)
            if let value = nearbyLines.compactMap(amount(in:)).first {
                return value
            }
        }
        return nil
    }

    private static func chineseCommercePaidAmount(from lines: [String]) -> String? {
        for line in lines.reversed() {
            if let value = amountAfterChineseFinalTotalLabel(in: line) {
                return value
            }
        }

        let paymentLabels = ["实付款", "實付款", "支付金额", "付款金额", "应付款", "實付", "实付"]
        for (index, line) in lines.enumerated().reversed() where paymentLabels.contains(where: { lineMatchesKeyword(line, $0) }) {
            let nearbyLines = lines.dropFirst(index).prefix(10)
            for nearbyLine in nearbyLines {
                if let value = amountAfterChineseFinalTotalLabel(in: nearbyLine) {
                    return value
                }
            }
            for nearbyLine in nearbyLines where !isChineseCommerceDiscountOrDisplayPriceLine(nearbyLine) {
                if let value = amount(in: nearbyLine) {
                    return value
                }
            }
        }

        return nil
    }

    private static func amountAfterChineseFinalTotalLabel(in line: String) -> String? {
        let labels = [
            "实付款", "實付款", "实付", "實付",
            "支付金额", "付款金额", "应付款", "合计", "合計", "合汁"
        ]
        let labelPattern = labels.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let pattern = #"(?:"# + labelPattern + #")[^¥￥$€£₩\d-]{0,12}(?:[$€£¥￥₩]\s*)?[-−]?(\d{1,6}(?:[,.]\d{3})*(?:[,.]\d{1,2})?|\d+(?:[,.]\d{1,2})?)"#
        return firstMatch(pattern: pattern, in: line, options: [.caseInsensitive]).map { normalizedAmountText($0) }
    }

    private static func isChineseCommerceDiscountOrDisplayPriceLine(_ line: String) -> Bool {
        let blockedKeywords = ["到手", "共减", "优惠", "减免", "立减", "券", "补贴", "原价", "商品总价"]
        if containsAnyKeyword(["合计", "合計", "实付款", "實付款", "支付金额", "付款金额"], in: line) {
            return false
        }
        return blockedKeywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    private static func largestAmount(from lines: [String]) -> String? {
        lines
            .compactMap { amount(in: $0) }
            .compactMap { value -> (text: String, amount: Decimal)? in
                guard let amount = DecimalParser.parse(value) else { return nil }
                return (value, amount)
            }
            .max { $0.amount < $1.amount }?
            .text
    }

    private static let fieldPool: [ReceiptFieldToken] = [
        ReceiptFieldToken(
            field: .total,
            tokens: [
                "TOTAL", "GRAND TOTAL", "AMOUNT DUE", "BALANCE DUE", "TOTAL DUE", "NET TOTAL", "PAYABLE",
                "合計", "合 計", "支払金額", "お買上金額", "現計", "現金合計",
                "合计", "總計", "应付", "应付金额", "支付金额",
                "實付款", "实付款", "應付", "应付款", "應付款", "付款金额", "订单金额", "BALANCE", "SUM", "PAID",
                "GESAMT", "SUMME", "BETRAG", "ZU ZAHLEN", "PAGADO", "IMPORTE", "TOTAL A PAGAR", "TOTAL TTC", "MONTANT",
                "TOTALE", "IMPORTO", "DA PAGARE", "TOTAAL", "TE BETALEN", "VALOR TOTAL", "TOTAL PAGO",
                "含計", "総計", "お会計", "お支払い", "【計】", "결제금액", "합계", "총액", "المجموع", "الإجمالي", "المبلغ"
            ]
        ),
        ReceiptFieldToken(
            field: .subtotal,
            tokens: [
                "SUBTOTAL", "SUB TOTAL", "SUB-TOTAL", "ITEM TOTAL", "MERCHANDISE TOTAL",
                "小計", "小 計", "商品計",
                "小计", "小計", "商品合计", "税前金额", "未税金额",
                "SUB TTL", "SUBTTL", "SUB TOT", "ZWISCHENSUMME", "SOUS-TOTAL", "SUBTOTALE", "SUB-TOTAAL", "SUBTOTAAL",
                "商品总价", "소계", "المجموع الفرعي"
            ]
        ),
        ReceiptFieldToken(
            field: .tax,
            tokens: [
                "TAX", "SALES TAX", "VAT", "GST", "IVA", "TVA", "MWST", "CGST", "SGST",
                "消費税", "税", "税額", "内税", "外税", "外税額", "内税額", "課税対象", "外税対象", "税抜", "税込",
                "税", "税额", "税費", "增值税", "营业税", "消费税",
                "TAX TOTAL", "TAX AMOUNT", "HST", "PST", "QST", "TPS", "TVQ", "TVH", "TVP", "STATE TAX", "CITY TAX", "TX",
                "UST", "MEHRWERTSTEUER", "IMPUESTO", "TAXE", "TAXE SUR LES PRODUITS ET SERVICES",
                "TAXE DE VENTE DU QUÉBEC", "TAXE DE VENTE DU QUEBEC", "QUEBEC SALES TAX",
                "IMPOSTA", "BTW", "BELASTING", "稅額", "内税対象", "外税 象", "課税対象", "课税对象",
                "부가세", "세금", "ضريبة", "الضريبة"
            ]
        ),
        ReceiptFieldToken(
            field: .tip,
            tokens: [
                "TIP", "TIPS", "GRATUITY", "SERVICE CHARGE", "SERVICE FEE", "OPTIONAL TIP",
                "チップ", "サービス料", "奉仕料",
                "小费", "小費", "服务费", "服務費",
                "SVC CHG", "PROPINA", "MANCIA", "GORJETA", "FOOI", "봉사료", "بقشيش"
            ]
        ),
        ReceiptFieldToken(
            field: .discount,
            tokens: [
                "DISCOUNT", "DISCOUNT AMOUNT", "SAVINGS", "COUPON",
                "割引", "値引", "値引額",
                "折扣", "优惠", "优惠金额",
                "DISC", "PROMO", "PROMOTION", "VOUCHER", "REBATE", "MARKDOWN", "LESS", "DEDUCTION", "减免", "할인"
            ]
        ),
        ReceiptFieldToken(
            field: .payment,
            tokens: [
                "PAID", "PAYMENT", "CASH", "CARD", "CREDIT", "DEBIT",
                "現金", "クレジット", "カード",
                "现金", "現金", "刷卡",
                "CREDIT CARD", "DEBIT CARD", "VISA", "MASTERCARD", "AMEX", "TENDER", "RECEIVED", "CHANGE", "CASHBACK",
                "釣銭", "找零"
            ]
        )
    ]

    private static func tokens(for field: ReceiptField) -> [String] {
        fieldPool
            .filter { $0.field == field }
            .flatMap(\.tokens)
    }

    private static let subtotalKeywords = tokens(for: .subtotal)
    private static let totalKeywords = tokens(for: .total)
    private static let taxKeywords = tokens(for: .tax)
    private static let taxableBaseKeywords = [
        "taxable amount", "taxable sales", "taxable subtotal", "外税対象", "外税 象", "内税対象", "課税対象", "课税对象"
    ]
    private static let tipKeywords = tokens(for: .tip)
    private static let discountKeywords = tokens(for: .discount)
    private static let paymentBoundaryKeywords = tokens(for: .payment)

    private static let nonSummaryTaxLines = [
        "vat included", "tax included", "gst included", "qst included", "tps included", "tvq included"
    ]

    private static let nonAmountTaxKeywords = nonSummaryTaxLines + taxableBaseKeywords + [
        "tax invoice", "tax id", "tax inv", "tax. inv", "tax no", "tax number"
    ]

    private static let nonTotalKeywords = subtotalKeywords + taxKeywords + tipKeywords + discountKeywords + paymentBoundaryKeywords + [
        "change"
    ]

    private static let moneyBoundaryKeywords = subtotalKeywords + taxKeywords + tipKeywords + discountKeywords + paymentBoundaryKeywords + totalKeywords + [
        "amount", "change"
    ]

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
        let hasCurrencySymbol = line.containsCurrencySymbol
        let pattern = #"(?<!\d)(?:[$€£¥￥₩]\s*)?([-−]?)(\d{1,6}(?:[,.]\s*\d{3})*(?:[,.]\d{1,2})?|\d+(?:[,.]\d{1,2})?)([-−]?)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).last,
              let matchRange = Range(match.range(at: 0), in: line),
              let leadingSignRange = Range(match.range(at: 1), in: line),
              let amountRange = Range(match.range(at: 2), in: line),
              let trailingSignRange = Range(match.range(at: 3), in: line) else { return nil }
        let matchedText = String(line[matchRange])
        if line[matchRange.upperBound...].trimmingCharacters(in: .whitespaces).hasPrefix("%") {
            return nil
        }
        let leadingSign = String(line[leadingSignRange])
        let trailingSign = String(line[trailingSignRange])
        let sign = (leadingSign == "-" || leadingSign == "−" || trailingSign == "-" || trailingSign == "−") ? "-" : ""
        let value = sign + normalizedAmountText(
            String(line[amountRange]),
            hasCurrencySymbol: hasCurrencySymbol || matchedText.containsCurrencySymbol,
            usesMinorUnits: currencyAmountUsesMinorUnits(in: matchedText, line: line)
        )
        guard value.contains(".") || hasCurrencySymbol || matchedText.containsCurrencySymbol || line.localizedCaseInsensitiveContains("合计") || line.localizedCaseInsensitiveContains("实付款") else {
            return nil
        }
        return correctedLeadingCurrencyOCR(in: value, from: line)
    }

    private static func normalizedAmountText(_ text: String, hasCurrencySymbol: Bool = false, usesMinorUnits: Bool = true) -> String {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.contains(","), !cleaned.contains(".") {
            let parts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2, let fraction = parts.last, (1...2).contains(fraction.count) {
                return parts.joined(separator: ".")
            }
        }
        if cleaned.contains(","), cleaned.contains(".") {
            let lastComma = cleaned.lastIndex(of: ",")
            let lastDot = cleaned.lastIndex(of: ".")
            if let lastComma, let lastDot, lastComma > lastDot {
                return cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
        }
        let withoutCommas = cleaned.replacingOccurrences(of: ",", with: "")
        if hasCurrencySymbol,
           usesMinorUnits,
           !withoutCommas.contains("."),
           withoutCommas.allSatisfy(\.isNumber),
           withoutCommas.count >= 3 {
            let centsIndex = withoutCommas.index(withoutCommas.endIndex, offsetBy: -2)
            return "\(withoutCommas[..<centsIndex]).\(withoutCommas[centsIndex...])"
        }
        return withoutCommas
    }

    private static func currencyAmountUsesMinorUnits(in matchedText: String, line: String) -> Bool {
        !containsZeroDecimalCurrencySymbol(matchedText) && !containsZeroDecimalCurrencySymbol(line)
    }

    private static func containsZeroDecimalCurrencySymbol(_ text: String) -> Bool {
        text.contains("¥") || text.contains("￥") || text.contains("₩") || text.contains("₫")
    }

    private static func correctedLeadingCurrencyOCR(in value: String, from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.containsCurrencySymbol,
              trimmed.range(of: #"^8\d{3,5}[,.]\d{2}$"#, options: .regularExpression) != nil,
              value.hasPrefix("8"),
              value.count >= 6 else {
            return value
        }
        let corrected = String(value.dropFirst())
        guard DecimalParser.parse(corrected) != nil else { return value }
        return corrected
    }

    private static func guessPlatformMerchant(from lines: [String]) -> String? {
        let text = lines.joined(separator: "\n")
        if let merchant = knownChineseMerchant(in: text) {
            return merchant
        }

        let blockedFragments = ["旧机", "补贴", "订单", "交易", "账单", "完成", "已发货", "详情", "支付", "收货", "商品"]
        for line in lines.prefix(30) {
            let cleaned = cleanMerchantLine(line)
            guard cleaned.count >= 2 else { continue }
            guard !isSuspiciousChineseMerchant(cleaned) else { continue }
            if cleaned.contains("店") || cleaned.contains("集团") || cleaned.contains("中国电信") {
                guard !blockedFragments.contains(where: { cleaned.contains($0) }) else { continue }
                return cleaned
            }
        }
        return nil
    }

    private static func knownChineseMerchant(in text: String) -> String? {
        let compactText = text.replacingOccurrences(of: " ", with: "")
        let merchants = [
            ("中国电信", ["中国电信", "浙江电信", "电信50元话费", "话费充值"]),
            ("中国移动", ["中国移动", "移动话费"]),
            ("中国联通", ["中国联通", "联通话费"]),
            ("支付宝充值中心", ["支付宝充值中心"])
        ]

        return merchants.first { _, keywords in
            keywords.contains { compactText.localizedCaseInsensitiveContains($0) }
        }?.0
    }

    private static func isSuspiciousChineseMerchant(_ merchant: String) -> Bool {
        let compact = merchant.replacingOccurrences(of: " ", with: "")
        return compact == "中国忠店" ||
            compact == "中国由店" ||
            compact.contains("忠店") ||
            compact.contains("由店")
    }

    private static func cleanMerchantLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "自营", with: "")
            .replacingOccurrences(of: "自 ", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "＞", with: "")
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isMerchantCandidate(_ line: String) -> Bool {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()
        guard cleaned.count >= 2 else { return false }
        guard !cleaned.containsAmount else { return false }
        guard !cleaned.isMostlyPunctuation else { return false }
        guard !isAddressLabel(lower) else { return false }
        guard !isGenericReceiptTitle(lower) else { return false }
        guard !lower.hasPrefix("tel") && !lower.hasPrefix("phone") else { return false }
        guard !lower.hasPrefix("date") && !lower.hasPrefix("time") else { return false }
        guard lower.range(of: #"\d{3}[-. ]?\d{3}[-. ]?\d{4}"#, options: .regularExpression) == nil else { return false }
        guard lower.range(of: #"(?:address|adress|adresse|adres|addr)?[:\s#-]*\d{1,6}\s+[a-z0-9 .,'-]+(?:st|street|ave|avenue|rd|road|blvd|drive|dr|lane|ln)\b"#, options: .regularExpression) == nil else { return false }
        let blocked = ["receipt", "invoice", "address", "adress", "adresse", "adres", "addr", "tel", "phone", "date", "time", "check", "table", "server", "cashier", "terminal", "merchant id", "store #", "order", "auth", "approval", "visa", "mastercard", "thank you", "duplicate", "账单", "详情", "订单", "支付", "付款", "交易", "完成", "已发货", "收货", "复制", "退款", "售后"]
        return !blocked.contains { lower.contains($0) }
    }

    private static func isGenericReceiptTitle(_ lowercasedLine: String) -> Bool {
        let lettersOnly = lowercasedLine.filter(\.isLetter)
        guard (4...9).contains(lettersOnly.count) else { return false }
        return editDistance(String(lettersOnly), "receipt") <= 3 ||
            editDistance(String(lettersOnly), "invoice") <= 2
    }

    private static func isMerchantSectionBoundary(_ line: String) -> Bool {
        line.containsAmount ||
            guessDate(from: [line]) != nil ||
            containsAnyKeyword(Self.moneyBoundaryKeywords, in: line)
    }

    private static func containsAnyKeyword(_ keywords: [String], in line: String) -> Bool {
        return keywords.contains { keyword in
            lineMatchesKeyword(line, keyword)
        }
    }

    private static func lineMatchesKeyword(_ line: String, _ keyword: String) -> Bool {
        let lineWords = canonicalWords(in: line)
        let keywordWords = canonicalWords(in: keyword)
        guard !lineWords.isEmpty, !keywordWords.isEmpty, lineWords.count >= keywordWords.count else {
            return false
        }
        if keywordWords.count == 1, keywordWords[0].count <= 3 {
            return lineWords.contains(keywordWords[0])
        }

        if line.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return true
        }

        for startIndex in 0...(lineWords.count - keywordWords.count) {
            let candidate = Array(lineWords[startIndex..<(startIndex + keywordWords.count)])
            let matches = zip(candidate, keywordWords).allSatisfy { word, expected in
                let allowedDistance = max(1, expected.count / 4)
                return word == expected || editDistance(word, expected) <= allowedDistance
            }
            if matches {
                return true
            }
        }

        let compactLine = lineWords.joined()
        let compactKeyword = keywordWords.joined()
        return compactLine.contains(compactKeyword) ||
            editDistance(compactLine, compactKeyword) <= max(1, compactKeyword.count / 4)
    }

    private static func canonicalWords(in text: String) -> [String] {
        let normalized = text.lowercased().map { character -> Character in
            switch character {
            case "0": "o"
            case "1", "!", "|", "ı": "l"
            case "5": "s"
            case "8": "b"
            default: character
            }
        }
        let canonical = String(normalized)
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        return canonical
            .split { !$0.isLetter }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0...right.count)

        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1]
            for (rightIndex, rightCharacter) in right.enumerated() {
                let substitution = previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                let insertion = current[rightIndex] + 1
                let deletion = previous[rightIndex + 1] + 1
                current.append(min(substitution, insertion, deletion))
            }
            previous = current
        }

        return previous.last ?? max(left.count, right.count)
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
        if lines.contains(where: { $0.contains("花呗") }) { return "Huabei" }
        if lines.contains(where: { $0.contains("支付宝") }) { return "Alipay" }
        if lines.contains(where: { $0.contains("微信") }) { return "WeChat Pay" }
        if lines.contains(where: { $0.contains("银行卡") }) { return "Bank card" }
        if lines.contains(where: { $0.contains("在线支付") }) { return "Online payment" }
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
        if let orderID = valueAfterChineseLabel(["订单编号", "订单信息", "交易号", "交易单号", "商户订单号"], from: lines, matching: #"(?<!\d)\d{10,24}(?!\d)"#) {
            return orderID
        }
        let pattern = #"(?:transaction|trans|txn|auth|approval|ref)[\s#:.-]*([A-Z0-9-]{4,})"#
        return firstMatch(pattern: pattern, in: lines.joined(separator: " "), options: [.caseInsensitive]) ?? ""
    }

    private static func guessReceiptNumber(from lines: [String]) -> String {
        if let orderID = valueAfterChineseLabel(["订单编号", "订单信息"], from: lines, matching: #"(?<!\d)\d{10,24}(?!\d)"#) {
            return orderID
        }
        let pattern = #"(?:receipt|check|order|invoice)[\s#:.-]*([A-Z0-9-]{3,})"#
        return firstMatch(pattern: pattern, in: lines.joined(separator: " "), options: [.caseInsensitive]) ?? ""
    }

    private static func guessStoreAddress(from lines: [String]) -> String {
        if let labeledAddress = lines.first(where: { isAddressLabel($0.lowercased()) }) {
            return labeledAddress
        }
        if let chineseAddress = lines.first(where: { line in
            line.contains("省") || line.contains("市") || line.contains("区") || line.contains("县") || line.contains("街道") || line.contains("路") || line.contains("院")
        }) {
            return chineseAddress
        }
        return lines.first { line in
            line.range(of: #"(?:address|adress|adresse|adres|addr)?[:\s#-]*\d{1,6}\s+[A-Za-z0-9 .,'-]+(?:st|street|ave|avenue|rd|road|blvd|drive|dr|lane|ln)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        } ?? ""
    }

    private static func isAddressLabel(_ lowercasedLine: String) -> Bool {
        lowercasedLine.range(of: #"^\s*(address|adress|adresse|adres|addr)\b"#, options: .regularExpression) != nil
    }

    private static func guessLineItems(from lines: [String]) -> [ReceiptLineItem] {
        let skipKeywords = ["subtotal", "total", "tax", "tip", "balance", "visa", "mastercard", "cash", "change", "amount due", "实付款", "商品总价", "合计", "订单", "支付", "收货", "配送"]
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
        if let code = CurrencyOption.code(for: text) {
            return code
        }
        if text.range(of: #"\d+[.]\d{2}"#, options: .regularExpression) != nil {
            return "USD"
        }
        return nil
    }

    private static func guessCategory(merchant: String, text: String, lineItems: [ReceiptLineItem]) -> ReceiptCategory? {
        let combinedText = ([merchant, text] + lineItems.map(\.name))
            .joined(separator: " ")
            .lowercased()

        let categoryKeywords: [(ReceiptCategory, [String])] = [
            (.meals, ["restaurant", "cafe", "coffee", "bakery", "bar", "grill", "pizza", "burger", "kitchen", "diner", "food", "meal", "sandwich", "茶", "咖啡", "餐", "饭", "面包", "奶茶"]),
            (.fuel, ["gas", "fuel", "petrol", "diesel", "shell", "chevron", "exxon", "mobil", "bp", "esso", "加油", "汽油", "柴油"]),
            (.travel, ["hotel", "motel", "airline", "flight", "airport", "taxi", "uber", "lyft", "train", "rail", "metro", "parking", "toll", "travel", "booking", "酒店", "机票", "机场", "出租车", "地铁", "停车"]),
            (.medical, ["pharmacy", "drug", "clinic", "hospital", "medical", "health", "dental", "doctor", "药", "医院", "诊所", "牙科", "医保"]),
            (.software, ["software", "subscription", "app store", "google play", "saas", "cloud", "hosting", "domain", "github", "adobe", "microsoft", "apple", "openai", "软件", "订阅", "云服务"]),
            (.office, ["office", "stationery", "printer", "paper", "ink", "toner", "supplies", "staples", "office depot", "办公", "文具", "打印", "纸张", "耗材"]),
            (.home, ["grocery", "supermarket", "market", "home", "house", "furniture", "hardware", "ikea", "walmart", "target", "costco", "超市", "家居", "家具", "五金"])
        ]

        return categoryKeywords.first { _, keywords in
            keywords.contains { combinedText.contains($0) }
        }?.0
    }

    private static func valueAfterChineseLabel(_ labels: [String], from lines: [String], matching pattern: String) -> String? {
        for (index, line) in lines.enumerated() where labels.contains(where: { line.contains($0) }) {
            if let value = firstMatch(pattern: "(\(pattern))", in: line) {
                return value
            }
            let nearbyText = lines.dropFirst(index + 1).prefix(16).joined(separator: " ")
            if let value = firstMatch(pattern: "(\(pattern))", in: nearbyText) {
                return value
            }
        }
        return nil
    }

    private static func recognizedKeys(
        merchant: String,
        category: ReceiptCategory?,
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
        if category != nil { keys.insert("category") }
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
        containsCurrencySymbol || range(of: #"\d+[.]\d{1,2}"#, options: .regularExpression) != nil
    }

    var containsCurrencySymbol: Bool {
        contains("$") || contains("€") || contains("£") || contains("¥") || contains("￥") || contains("₩") || contains("ر.س") || contains("س.ر")
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

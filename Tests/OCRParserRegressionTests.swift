import Foundation

private struct ParserCase {
    let name: String
    let lines: [String]
    let subtotal: String
    let tax: String
    let total: String
}

@main
enum OCRParserRegressionTests {
    static func main() {
        let cases = [
            ParserCase(
                name: "English decimal",
                lines: ["CORNER SHOP", "SUBTOTAL $12.34", "SALES TAX $0.99", "TOTAL $13.33"],
                subtotal: "12.34", tax: "0.99", total: "13.33"
            ),
            ParserCase(
                name: "Chinese CNY decimal",
                lines: ["便利店", "小计 ¥12.34", "税额 ¥0.99", "合计 ¥13.33"],
                subtotal: "12.34", tax: "0.99", total: "13.33"
            ),
            ParserCase(
                name: "German decimal comma",
                lines: ["MARKT", "ZWISCHENSUMME 12,34 €", "MWST 2,34 €", "GESAMT 14,68 €"],
                subtotal: "12.34", tax: "2.34", total: "14.68"
            ),
            ParserCase(
                name: "French narrow-space thousands",
                lines: ["MAGASIN", "SOUS-TOTAL 1\u{202f}234,56 €", "TVA 234,57 €", "TOTAL TTC 1\u{202f}469,13 €"],
                subtotal: "1234.56", tax: "234.57", total: "1469.13"
            ),
            ParserCase(
                name: "Arabic digits and separators",
                lines: ["المتجر", "المجموع الفرعي ١٢٫٣٤ ر.س", "ضريبة ٠٫٩٩ ر.س", "الإجمالي ١٣٫٣٣ ر.س"],
                subtotal: "12.34", tax: "0.99", total: "13.33"
            ),
            ParserCase(
                name: "Dollar integer thousands",
                lines: ["STORE", "TOTAL $1,234"],
                subtotal: "", tax: "", total: "1234"
            ),
            ParserCase(
                name: "Japanese zero-decimal yen",
                lines: ["東京ストア", "合計 ¥1234"],
                subtotal: "", tax: "", total: "1234"
            ),
            ParserCase(
                name: "Amazon two-column Vision order",
                lines: [
                    "Amazon.com", "410 Terry Avenue North", "Seattle, WA 98109", "1-888-280-4331",
                    "11/15/2024, 2:34:18 PM", "Order Number", "Sold By", "#112-8847362-1456892",
                    "Amazon.com Services LLC", "Anker USB C Charger 20W", "2", "Amazon Basics AA Batteries",
                    "(48-Pack)", "1 Fire TV Stick 4K", "1 Echo Dot (5th Gen)", "Subtotal",
                    "Shipping & Handling", "Tax", "Order Total", "$12.99", "$18.99", "Card Type",
                    "Card Number", "Amount Charged", "$49.99", "$49.99", "$131.96", "$0.00",
                    "$11.86", "$143.82", "Visa", "****4523", "$143.82", "Thanks for shopping with us!"
                ],
                subtotal: "131.96", tax: "11.86", total: "143.82"
            )
        ]

        var failures = 0
        for test in cases {
            let result = OCRService.parseRecognizedLines(test.lines)
            let actual = [result.subtotalText, result.taxText, result.totalText]
            let expected = [test.subtotal, test.tax, test.total]
            if actual == expected {
                print("PASS \(test.name): \(actual)")
            } else {
                failures += 1
                print("FAIL \(test.name): expected=\(expected) actual=\(actual)")
            }
        }

        let positionedAmazon = OCRService.parseRecognizedLines([
            OCRRecognizedLine(text: "Subtotal", boundingBox: CGRect(x: 0.36, y: 0.42, width: 0.20, height: 0.03)),
            OCRRecognizedLine(text: "Shipping & Handling", boundingBox: CGRect(x: 0.36, y: 0.38, width: 0.30, height: 0.03)),
            OCRRecognizedLine(text: "Tax", boundingBox: CGRect(x: 0.36, y: 0.34, width: 0.08, height: 0.03)),
            OCRRecognizedLine(text: "Order Total", boundingBox: CGRect(x: 0.36, y: 0.30, width: 0.20, height: 0.03)),
            OCRRecognizedLine(text: "$131.96", boundingBox: CGRect(x: 0.80, y: 0.42, width: 0.14, height: 0.03)),
            OCRRecognizedLine(text: "$0.00", boundingBox: CGRect(x: 0.84, y: 0.38, width: 0.10, height: 0.03)),
            OCRRecognizedLine(text: "$11.86", boundingBox: CGRect(x: 0.82, y: 0.34, width: 0.12, height: 0.03)),
            OCRRecognizedLine(text: "$143.82", boundingBox: CGRect(x: 0.80, y: 0.30, width: 0.14, height: 0.03))
        ])
        let positionedActual = [positionedAmazon.subtotalText, positionedAmazon.taxText, positionedAmazon.totalText]
        let positionedExpected = ["131.96", "11.86", "143.82"]
        if positionedActual == positionedExpected {
            print("PASS positioned two-column summary: \(positionedActual)")
        } else {
            failures += 1
            print("FAIL positioned two-column summary: expected=\(positionedExpected) actual=\(positionedActual)")
        }

        let amazonFastPath = OCRService.parseRecognizedLines(cases.last!.lines)
        if OCRService.isReliableRecognitionResult(amazonFastPath) {
            print("PASS reliable Amazon result uses fast path")
        } else {
            failures += 1
            print("FAIL reliable Amazon result did not use fast path")
        }

        let japaneseCurrencyMismatch = OCRService.parseRecognizedLines([
            "あおきスーパー",
            "合計 ¥600",
            "Ft"
        ])
        let japaneseReviewKeys: Set<String> = ["merchant", "currency", "total"]
        if japaneseCurrencyMismatch.currencyCode == "HUF",
           japaneseReviewKeys.isSubset(of: japaneseCurrencyMismatch.lowConfidenceFieldKeys),
           !OCRService.isReliableRecognitionResult(japaneseCurrencyMismatch) {
            print("PASS Japanese currency mismatch requires review")
        } else {
            failures += 1
            print("FAIL Japanese currency mismatch: currency=\(japaneseCurrencyMismatch.currencyCode ?? "nil") review=\(japaneseCurrencyMismatch.lowConfidenceFieldKeys)")
        }

        let garbledMerchant = OCRService.parseRecognizedLines([
            "*FTTHETE",
            "TOTAL 600",
            "Ft"
        ])
        if japaneseReviewKeys.isSubset(of: garbledMerchant.lowConfidenceFieldKeys) {
            print("PASS garbled merchant requires currency and total review")
        } else {
            failures += 1
            print("FAIL garbled merchant review: review=\(garbledMerchant.lowConfidenceFieldKeys)")
        }

        let inconsistent = OCRService.parseRecognizedLines([
            "STORE",
            "SUBTOTAL $10.00",
            "SALES TAX $1.00",
            "TOTAL $15.00"
        ])
        let expectedReviewKeys: Set<String> = ["subtotal", "tax", "total"]
        if expectedReviewKeys.isSubset(of: inconsistent.lowConfidenceFieldKeys) {
            print("PASS inconsistent summary requires review")
        } else {
            failures += 1
            print("FAIL inconsistent summary review keys: \(inconsistent.lowConfidenceFieldKeys)")
        }

        let kfcPaymentReceipt = OCRService.parseRecognizedLines([
            "Family Fill Up", "20.00", "Tax", "DRIVE THRU", "ETender Credit", "Change",
            "1.73", "$21.73", "$21.73", "$0.00", "CHARGE DETAIL: SALE"
        ])
        if kfcPaymentReceipt.totalText == "21.73" {
            print("PASS payment receipt derives total from tender and zero change")
        } else {
            failures += 1
            print("FAIL payment receipt total: \(kfcPaymentReceipt.totalText)")
        }

        let roundedCashReceipt = OCRService.parseRecognizedLines([
            "TOTAL AMT.", "ROUNDING ADJ.", "ROUND", "CASH", "CHANGE",
            "60.31", "-0.01", "60.30", "70.30", "10.00"
        ])
        if roundedCashReceipt.totalText == "60.30" {
            print("PASS rounded cash receipt uses tender minus change")
        } else {
            failures += 1
            print("FAIL rounded cash receipt total: \(roundedCashReceipt.totalText)")
        }

        let positionedRoundedCashReceipt = OCRService.parseRecognizedLines([
            OCRRecognizedLine(text: "TOTAL AMT.", boundingBox: CGRect(x: 0.10, y: 0.50, width: 0.30, height: 0.03)),
            OCRRecognizedLine(text: "60.31", boundingBox: CGRect(x: 0.80, y: 0.50, width: 0.12, height: 0.03)),
            OCRRecognizedLine(text: "CHANGE", boundingBox: CGRect(x: 0.10, y: 0.30, width: 0.20, height: 0.03)),
            OCRRecognizedLine(text: "60.30", boundingBox: CGRect(x: 0.80, y: 0.34, width: 0.12, height: 0.03)),
            OCRRecognizedLine(text: "70.30", boundingBox: CGRect(x: 0.80, y: 0.32, width: 0.12, height: 0.03)),
            OCRRecognizedLine(text: "10.00", boundingBox: CGRect(x: 0.80, y: 0.30, width: 0.12, height: 0.03))
        ])
        if positionedRoundedCashReceipt.totalText == "60.30" {
            print("PASS positioned rounded cash receipt uses tender minus change")
        } else {
            failures += 1
            print("FAIL positioned rounded cash receipt total: \(positionedRoundedCashReceipt.totalText)")
        }

        let shopifyOrder = OCRService.parseRecognizedLines([
            "Subtotal", "Order discount", "Shipping", "Taxes", "Total", "Total paid today",
            "$10.48", "-$5.00", "$10.00 Free", "$0.00", "$5.48 USD", "$0.00 USD"
        ])
        if shopifyOrder.totalText == "5.48" {
            print("PASS order total is not replaced by total paid today")
        } else {
            failures += 1
            print("FAIL Shopify order total: \(shopifyOrder.totalText)")
        }

        if CurrencyOption.code(for: "Walmart ENTRY TOTAL $144.02") == "USD" {
            print("PASS currency tokens do not match ordinary words")
        } else {
            failures += 1
            print("FAIL currency token boundary")
        }

        let decimalCases: [(String, String)] = [
            ("12,34", "12.34"),
            ("1.234,56", "1234.56"),
            ("1,234.56", "1234.56"),
            ("1\u{202f}234,56", "1234.56"),
            ("١٢٫٣٤", "12.34")
        ]
        for (input, expected) in decimalCases {
            let actual = DecimalParser.parse(input).map { NSDecimalNumber(decimal: $0).stringValue }
            if actual == expected {
                print("PASS decimal parser \(input): \(expected)")
            } else {
                failures += 1
                print("FAIL decimal parser \(input): expected=\(expected) actual=\(actual ?? "nil")")
            }
        }

        var draft = ReceiptDraft(
            subtotalText: "10.00",
            totalText: "15.00",
            taxText: "1.00"
        )
        draft.reconcileAmountsKeepingTotal()
        if draft.subtotalText == "10.00",
           draft.taxText == "1.00",
           draft.totalText == "15.00",
           expectedReviewKeys.isSubset(of: draft.lowConfidenceFieldKeys) {
            print("PASS inconsistent summary is not overwritten")
        } else {
            failures += 1
            print("FAIL inconsistent summary mutation: subtotal=\(draft.subtotalText) tax=\(draft.taxText) total=\(draft.totalText) review=\(draft.lowConfidenceFieldKeys)")
        }

        guard failures == 0 else {
            print("FAILED \(failures)/\(cases.count) OCR parser cases")
            exit(1)
        }
        print("PASSED \(cases.count)/\(cases.count) OCR parser cases")
    }
}

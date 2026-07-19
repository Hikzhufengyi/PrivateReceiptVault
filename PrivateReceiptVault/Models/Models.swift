import Foundation
import SwiftUI

struct CurrencyOption: Identifiable, Equatable {
    let code: String
    let symbol: String
    let nameKey: String
    let ocrTokens: [String]

    init(code: String, symbol: String, nameKey: String, ocrTokens: [String] = []) {
        self.code = code
        self.symbol = symbol
        self.nameKey = nameKey
        self.ocrTokens = ocrTokens
    }

    var id: String { code }

    var localizedName: String {
        String(localized: String.LocalizationValue(nameKey))
    }

    var displayName: String {
        "\(code) · \(symbol) · \(localizedName)"
    }

    static let pool: [CurrencyOption] = [

        CurrencyOption(
            code: "USD",
            symbol: "$",
            nameKey: "US Dollar",
            ocrTokens: [
                "USD", "US$", "US $", "$",
                "USD$", "DOLLAR", "DOLLARS"
            ]
        ),

        CurrencyOption(
            code: "EUR",
            symbol: "€",
            nameKey: "Euro",
            ocrTokens: [
                "EUR", "EURO", "EUROS",
                "€", "EUR€"
            ]
        ),

        CurrencyOption(
            code: "GBP",
            symbol: "£",
            nameKey: "British Pound",
            ocrTokens: [
                "GBP", "£",
                "POUND", "POUNDS",
                "GBP£"
            ]
        ),

        CurrencyOption(
            code: "JPY",
            symbol: "¥",
            nameKey: "Japanese Yen",
            ocrTokens: [
                "JPY",
                "¥", "￥",
                "円",
                "YEN"
            ]
        ),

        CurrencyOption(
            code: "CNY",
            symbol: "¥",
            nameKey: "Chinese Yuan",
            ocrTokens: [
                "CNY",
                "RMB",
                "人民币",
                "人民幣",
                "¥",
                "￥",
                "元",
                "圆",
                "圓",
                "YUAN"
            ]
        ),

        CurrencyOption(
            code: "HKD",
            symbol: "HK$",
            nameKey: "Hong Kong Dollar",
            ocrTokens: [
                "HKD",
                "HK$",
                "HK $",
                "香港",
                "港币",
                "港幣",
                "尖沙咀",
                "旺角",
                "油麻地",
                "佐敦",
                "中環",
                "灣仔",
                "銅鑼灣",
                "九龍",
                "新界",
                "沙田",
                "屯門",
                "元朗",
                "荃灣",
                "觀塘",
                "深水埗",
                "鰂魚涌",
                "筲箕灣",
                "漆咸道",
                "HONG KONG",
                "KOWLOON",
                "TSIM SHA TSUI",
                "MONG KOK",
                "CENTRAL",
                "WAN CHAI",
                "CAUSEWAY BAY",
                "HONG KONG DOLLAR"
            ]
        ),

        CurrencyOption(
            code: "SGD",
            symbol: "S$",
            nameKey: "Singapore Dollar",
            ocrTokens: [
                "SGD",
                "S$",
                "SG $",
                "SINGAPORE DOLLAR"
            ]
        ),

        CurrencyOption(
            code: "CAD",
            symbol: "C$",
            nameKey: "Canadian Dollar",
            ocrTokens: [
                "CAD",
                "C$",
                "CA$",
                "CAN$",
                "CANADIAN DOLLAR"
            ]
        ),

        CurrencyOption(
            code: "AUD",
            symbol: "A$",
            nameKey: "Australian Dollar",
            ocrTokens: [
                "AUD",
                "A$",
                "AU$",
                "AUSTRALIAN DOLLAR"
            ]
        ),

        CurrencyOption(
            code: "NZD",
            symbol: "NZ$",
            nameKey: "New Zealand Dollar",
            ocrTokens: [
                "NZD",
                "NZ$",
                "NZ $",
                "NEW ZEALAND DOLLAR"
            ]
        ),

        CurrencyOption(
            code: "CHF",
            symbol: "Fr",
            nameKey: "Swiss Franc",
            ocrTokens: [
                "CHF",
                "SFR",
                "FR.",
                "SWISS FRANC"
            ]
        ),

        CurrencyOption(
            code: "SEK",
            symbol: "kr",
            nameKey: "Swedish Krona",
            ocrTokens: [
                "SEK",
                "KR",
                "KRONOR"
            ]
        ),

        CurrencyOption(
            code: "NOK",
            symbol: "kr",
            nameKey: "Norwegian Krone",
            ocrTokens: [
                "NOK",
                "KR",
                "NORWEGIAN KRONE"
            ]
        ),

        CurrencyOption(
            code: "DKK",
            symbol: "kr",
            nameKey: "Danish Krone",
            ocrTokens: [
                "DKK",
                "KR",
                "DANISH KRONE"
            ]
        ),

        CurrencyOption(
            code: "PLN",
            symbol: "zł",
            nameKey: "Polish Zloty",
            ocrTokens: [
                "PLN",
                "ZŁ",
                "ZL",
                "ZLOTY"
            ]
        ),

        CurrencyOption(
            code: "CZK",
            symbol: "Kč",
            nameKey: "Czech Koruna",
            ocrTokens: [
                "CZK",
                "KČ",
                "KC"
            ]
        ),

        CurrencyOption(
            code: "HUF",
            symbol: "Ft",
            nameKey: "Hungarian Forint",
            ocrTokens: [
                "HUF",
                "FT",
                "FORINT"
            ]
        ),

        CurrencyOption(
            code: "RON",
            symbol: "lei",
            nameKey: "Romanian Leu",
            ocrTokens: [
                "RON",
                "LEI",
                "LEU"
            ]
        ),

        CurrencyOption(
            code: "TRY",
            symbol: "₺",
            nameKey: "Turkish Lira",
            ocrTokens: [
                "TRY",
                "TL",
                "₺",
                "LIRA"
            ]
        ),

        CurrencyOption(
            code: "ILS",
            symbol: "₪",
            nameKey: "Israeli Shekel",
            ocrTokens: [
                "ILS",
                "₪",
                "SHEKEL"
            ]
        ),

        CurrencyOption(
            code: "AED",
            symbol: "د.إ",
            nameKey: "UAE Dirham",
            ocrTokens: [
                "AED",
                "د.إ",
                "DIRHAM"
            ]
        ),

        CurrencyOption(
            code: "SAR",
            symbol: "ر.س",
            nameKey: "Saudi Riyal",
            ocrTokens: [
                "SAR",
                "ر.س",
                "س.ر",
                "RIYAL"
            ]
        ),

        CurrencyOption(
            code: "QAR",
            symbol: "ر.ق",
            nameKey: "Qatari Riyal",
            ocrTokens: [
                "QAR",
                "ر.ق",
                "RIYAL"
            ]
        ),

        CurrencyOption(
            code: "KWD",
            symbol: "د.ك",
            nameKey: "Kuwaiti Dinar",
            ocrTokens: [
                "KWD",
                "د.ك",
                "DINAR"
            ]
        ),

        CurrencyOption(
            code: "INR",
            symbol: "₹",
            nameKey: "Indian Rupee",
            ocrTokens: [
                "INR",
                "₹",
                "RS",
                "RS.",
                "RUPEE",
                "RUPEES"
            ]
        ),

        CurrencyOption(
            code: "KRW",
            symbol: "₩",
            nameKey: "South Korean Won",
            ocrTokens: [
                "KRW",
                "₩",
                "원",
                "WON"
            ]
        ),

        CurrencyOption(
            code: "THB",
            symbol: "฿",
            nameKey: "Thai Baht",
            ocrTokens: [
                "THB",
                "฿",
                "BAHT"
            ]
        ),

        CurrencyOption(
            code: "MYR",
            symbol: "RM",
            nameKey: "Malaysian Ringgit",
            ocrTokens: [
                "MYR",
                "RM",
                "RINGGIT"
            ]
        ),

        CurrencyOption(
            code: "IDR",
            symbol: "Rp",
            nameKey: "Indonesian Rupiah",
            ocrTokens: [
                "IDR",
                "RP",
                "RP.",
                "RUPIAH"
            ]
        ),

        CurrencyOption(
            code: "PHP",
            symbol: "₱",
            nameKey: "Philippine Peso",
            ocrTokens: [
                "PHP",
                "₱",
                "PESO"
            ]
        ),

        CurrencyOption(
            code: "VND",
            symbol: "₫",
            nameKey: "Vietnamese Dong",
            ocrTokens: [
                "VND",
                "₫",
                "VNĐ",
                "DONG"
            ]
        ),

        CurrencyOption(
            code: "TWD",
            symbol: "NT$",
            nameKey: "New Taiwan Dollar",
            ocrTokens: [
                "TWD",
                "NT$",
                "NT $",
                "新台币",
                "新台幣"
            ]
        ),

        CurrencyOption(
            code: "MXN",
            symbol: "MX$",
            nameKey: "Mexican Peso",
            ocrTokens: [
                "MXN",
                "MX$",
                "MX $",
                "PESO"
            ]
        ),

        CurrencyOption(
            code: "BRL",
            symbol: "R$",
            nameKey: "Brazilian Real",
            ocrTokens: [
                "BRL",
                "R$",
                "REAL"
            ]
        ),

        CurrencyOption(
            code: "ZAR",
            symbol: "R",
            nameKey: "South African Rand",
            ocrTokens: [
                "ZAR",
                "RAND"
            ]
        )
    ]

    static let common: [CurrencyOption] = pool

    static var defaultCode: String {
        let current = Locale.current.currency?.identifier ?? "USD"
        return pool.contains { $0.code == current } ? current : "USD"
    }

    static func code(for text: String) -> String? {
        let normalizedText = text.uppercased()
        if text.contains("¥") || text.contains("￥") {
            let japaneseSignals = ["日本", "税込", "税抜", "消費税", "内税", "外税", "現金", "釣銭", "お釣り", "預り", "お預り", "円", "県", "郡", "村", "町", "白川郷", "民芸品店"]
            if japaneseSignals.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
                return "JPY"
            }
        }
        let tokenPairs = pool
            .flatMap { option in option.ocrTokens.map { (code: option.code, token: $0.uppercased()) } }
            .filter { !$0.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.token.count == $1.token.count {
                    return $0.code < $1.code
                }
                return $0.token.count > $1.token.count
            }

        for pair in tokenPairs {
            if normalizedText.contains(pair.token) {
                return pair.code
            }
        }

        if text.contains("¥") {
            let lowercasedText = text.lowercased()
            return lowercasedText.contains("jpy") || lowercasedText.contains("japan") || lowercasedText.contains("yen") ? "JPY" : "CNY"
        }
        return nil
    }
}

enum ReceiptCategory: String, CaseIterable, Codable, Identifiable {
    case meals = "Meals"
    case travel = "Travel"
    case fuel = "Fuel"
    case office = "Office"
    case medical = "Medical"
    case home = "Home"
    case software = "Software"
    case other = "Other"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }

    var systemImage: String {
        switch self {
        case .meals: "fork.knife"
        case .travel: "airplane"
        case .fuel: "fuelpump"
        case .office: "briefcase"
        case .medical: "cross.case"
        case .home: "house"
        case .software: "laptopcomputer"
        case .other: "tag"
        }
    }

    var color: Color {
        switch self {
        case .meals: Color(red: 0.82, green: 0.23, blue: 0.25)
        case .travel: Color(red: 0.12, green: 0.46, blue: 0.82)
        case .fuel: Color(red: 0.95, green: 0.58, blue: 0.16)
        case .office: Color(red: 0.38, green: 0.38, blue: 0.45)
        case .medical: Color(red: 0.04, green: 0.62, blue: 0.47)
        case .home: Color(red: 0.48, green: 0.34, blue: 0.70)
        case .software: Color(red: 0.10, green: 0.58, blue: 0.66)
        case .other: Color(red: 0.50, green: 0.52, blue: 0.56)
        }
    }
}

enum ReimbursementStatus: String, CaseIterable, Codable, Identifiable {
    case notReimbursable = "Not reimbursable"
    case reimbursable = "Reimbursable"
    case reimbursed = "Reimbursed"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .notReimbursable: "不报销"
        case .reimbursable: "可报销"
        case .reimbursed: "已报销"
        }
    }
}

struct Receipt: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var merchant: String
    var date: Date
    var subtotal: Decimal?
    var total: Decimal
    var tax: Decimal?
    var taxRate: Decimal?
    var tip: Decimal?
    var currencyCode: String
    var category: ReceiptCategory
    var paymentMethod: String
    var cardLast4: String
    var transactionID: String
    var storeAddress: String
    var receiptNumber: String
    var lineItems: [ReceiptLineItem]
    var project: String
    var notes: String
    var recognizedText: String
    var imageFileName: String?
    var reimbursementStatus: ReimbursementStatus?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    static var sample: Receipt {
        Receipt(
            merchant: "Coffee House",
            date: .now,
            subtotal: 11.88,
            total: 12.80,
            tax: 0.92,
            taxRate: 7.75,
            tip: nil,
            currencyCode: CurrencyOption.defaultCode,
            category: .meals,
            paymentMethod: "Visa",
            cardLast4: "4242",
            transactionID: "A12345",
            storeAddress: "100 Main Street",
            receiptNumber: "R-1001",
            lineItems: [
                ReceiptLineItem(name: "Coffee", quantity: 1, amount: 4.80),
                ReceiptLineItem(name: "Sandwich", quantity: 1, amount: 7.08)
            ],
            project: "Client Trip",
            notes: "",
            recognizedText: ""
        )
    }
}

extension Receipt {
    var reimbursementState: ReimbursementStatus {
        reimbursementStatus ?? .notReimbursable
    }
}

struct ReceiptLineItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var quantity: Decimal?
    var amount: Decimal?
}

struct ReceiptDraft {
    var merchant: String = ""
    var date: Date = .now
    var subtotalText: String = ""
    var totalText: String = ""
    var taxText: String = ""
    var taxRateText: String = ""
    var tipText: String = ""
    var currencyCode: String = CurrencyOption.defaultCode
    var category: ReceiptCategory = .other
    var reimbursementStatus: ReimbursementStatus = .notReimbursable
    var paymentMethod: String = ""
    var cardLast4: String = ""
    var transactionID: String = ""
    var storeAddress: String = ""
    var receiptNumber: String = ""
    var lineItems: [ReceiptLineItem] = []
    var project: String = ""
    var notes: String = ""
    var recognizedText: String = ""
    var recognizedFieldKeys: Set<String> = []
    var lowConfidenceFieldKeys: Set<String> = []
    var imageData: Data?
    var imageFileName: String?

    var total: Decimal {
        DecimalParser.parse(totalText) ?? 0
    }

    var subtotal: Decimal? {
        DecimalParser.parse(subtotalText)
    }

    var tax: Decimal? {
        DecimalParser.parse(taxText)
    }

    var taxRate: Decimal? {
        DecimalParser.parse(taxRateText.replacingOccurrences(of: "%", with: ""))
    }

    var tip: Decimal? {
        DecimalParser.parse(tipText)
    }

    mutating func reconcileAmountsKeepingTotal() {
        guard total > Decimal.zero else { return }

        if let tax, tax < Decimal.zero || tax > total * Decimal(string: "0.30")! {
            taxText = ""
            lowConfidenceFieldKeys.insert("tax")
        }

        let tipAmount = tip ?? Decimal.zero
        if let subtotal, let tax, amountsMatch(total, subtotal + tax + tipAmount) {
            return
        }

        if subtotal != nil, tax != nil {
            lowConfidenceFieldKeys.formUnion(["subtotal", "tax", "total"])
            return
        }

        if let subtotal, tax == nil, subtotal <= total {
            let inferredTax = total - subtotal - tipAmount
            if inferredTax >= Decimal.zero, inferredTax <= total * Decimal(string: "0.30")! {
                taxText = Self.currencyText(inferredTax)
                lowConfidenceFieldKeys.insert("tax")
                return
            }
        }

        if let tax {
            if let subtotal, subtotal > total {
                lowConfidenceFieldKeys.formUnion(["subtotal", "tax", "total"])
                return
            }
            let inferredSubtotal = total - tax - tipAmount
            if inferredSubtotal >= Decimal.zero {
                subtotalText = Self.currencyText(inferredSubtotal)
                lowConfidenceFieldKeys.insert("subtotal")
            }
        }
    }

    private func amountsMatch(_ lhs: Decimal, _ rhs: Decimal) -> Bool {
        let tolerance = Decimal(string: "0.02")!
        let difference = lhs - rhs
        return (difference < Decimal.zero ? -difference : difference) <= tolerance
    }

    private static func currencyText(_ value: Decimal) -> String {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}

enum DecimalParser {
    static func parse(_ text: String) -> Decimal? {
        var cleaned = text
        let replacements = [
            ("٠", "0"), ("١", "1"), ("٢", "2"), ("٣", "3"), ("٤", "4"),
            ("٥", "5"), ("٦", "6"), ("٧", "7"), ("٨", "8"), ("٩", "9"),
            ("۰", "0"), ("۱", "1"), ("۲", "2"), ("۳", "3"), ("۴", "4"),
            ("۵", "5"), ("۶", "6"), ("۷", "7"), ("۸", "8"), ("۹", "9"),
            ("٫", "."), ("٬", ","), ("\u{00A0}", ""), ("\u{202F}", ""), ("\u{2009}", "")
        ]
        for (source, replacement) in replacements {
            cleaned = cleaned.replacingOccurrences(of: source, with: replacement)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        let commaIndex = cleaned.lastIndex(of: ",")
        let dotIndex = cleaned.lastIndex(of: ".")
        if let commaIndex, let dotIndex {
            let decimalSeparator = commaIndex > dotIndex ? "," : "."
            let groupingSeparator = decimalSeparator == "," ? "." : ","
            cleaned = cleaned.replacingOccurrences(of: groupingSeparator, with: "")
            if decimalSeparator == "," {
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            }
        } else if let commaIndex {
            let fractionalCount = cleaned.distance(from: cleaned.index(after: commaIndex), to: cleaned.endIndex)
            cleaned = fractionalCount == 1 || fractionalCount == 2
                ? cleaned.replacingOccurrences(of: ",", with: ".")
                : cleaned.replacingOccurrences(of: ",", with: "")
        }
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}

enum ExpenseReportStatus: String, CaseIterable, Codable, Identifiable {
    case draft = "Draft"
    case submitted = "Submitted"
    case paid = "Paid"
    case archived = "Archived"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
}

struct ExpenseReport: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var companyName: String = ""
    var claimantName: String = ""
    var department: String = ""
    var startDate: Date
    var endDate: Date
    var status: ExpenseReportStatus
    var receiptIDs: [UUID]
    var notes: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct ExpenseReportDraft {
    var title: String = ""
    var companyName: String = ""
    var claimantName: String = ""
    var department: String = ""
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var endDate: Date = .now
    var status: ExpenseReportStatus = .draft
    var receiptIDs: [UUID] = []
    var notes: String = ""
}

struct ReceiptVaultBackup: Codable {
    var schemaVersion: Int = 1
    var exportedAt: Date = Date()
    var receipts: [Receipt]
    var expenseReports: [ExpenseReport]
    var images: [String: Data] = [:]
}

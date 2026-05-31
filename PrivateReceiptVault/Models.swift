import Foundation
import SwiftUI

struct CurrencyOption: Identifiable, Equatable {
    let code: String
    let symbol: String
    let nameKey: String

    var id: String { code }

    var localizedName: String {
        String(localized: String.LocalizationValue(nameKey))
    }

    var displayName: String {
        "\(code) · \(symbol) · \(localizedName)"
    }

    static let common: [CurrencyOption] = [
        CurrencyOption(code: "USD", symbol: "$", nameKey: "US Dollar"),
        CurrencyOption(code: "EUR", symbol: "€", nameKey: "Euro"),
        CurrencyOption(code: "GBP", symbol: "£", nameKey: "British Pound"),
        CurrencyOption(code: "JPY", symbol: "¥", nameKey: "Japanese Yen"),
        CurrencyOption(code: "CNY", symbol: "¥", nameKey: "Chinese Yuan"),
        CurrencyOption(code: "CAD", symbol: "C$", nameKey: "Canadian Dollar"),
        CurrencyOption(code: "AUD", symbol: "A$", nameKey: "Australian Dollar"),
        CurrencyOption(code: "CHF", symbol: "Fr", nameKey: "Swiss Franc"),
        CurrencyOption(code: "HKD", symbol: "HK$", nameKey: "Hong Kong Dollar"),
        CurrencyOption(code: "SGD", symbol: "S$", nameKey: "Singapore Dollar")
    ]

    static var defaultCode: String {
        let current = Locale.current.currency?.identifier ?? "USD"
        return common.contains { $0.code == current } ? current : "USD"
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
}

enum DecimalParser {
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

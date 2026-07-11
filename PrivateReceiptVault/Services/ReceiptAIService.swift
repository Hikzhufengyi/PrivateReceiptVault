import Foundation

struct ReceiptAIUnderstanding {
    var category: ReceiptCategory
    var notes: String
    var reimbursementStatus: ReimbursementStatus
}

enum ReceiptAIService {
    static func understand(result: OCRResult, currentDraft: ReceiptDraft) -> ReceiptAIUnderstanding {
        let combinedText = [
            result.merchant,
            result.text,
            result.lineItems.map(\.name).joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()

        let category = result.category ?? inferredCategory(from: combinedText)
        let reimbursementStatus = inferredReimbursementStatus(category: category, text: combinedText)
        let notes = generatedNotes(
            merchant: result.merchant.isEmpty ? currentDraft.merchant : result.merchant,
            category: category,
            totalText: result.totalText.isEmpty ? currentDraft.totalText : result.totalText,
            currencyCode: result.currencyCode ?? currentDraft.currencyCode,
            text: combinedText,
            paymentMethod: result.paymentMethod,
            lineItems: result.lineItems
        )

        return ReceiptAIUnderstanding(
            category: category,
            notes: notes,
            reimbursementStatus: reimbursementStatus
        )
    }

    private static func inferredCategory(from text: String) -> ReceiptCategory {
        let text = semanticReceiptText(from: text)
        let rules: [(ReceiptCategory, [String])] = [
            (.travel, ["酒店", "机票", "机场", "火车", "高铁", "打车", "出租车", "滴滴", "uber", "lyft", "parking", "toll", "hotel", "flight", "taxi"]),
            (.meals, ["餐", "餐廳", "餐厅", "堂食", "饭", "咖啡", "奶茶", "茶", "面包", "肥牛", "粉絲", "粉丝", "時蔬", "时蔬", "小肉排", "港味", "restaurant", "coffee", "cafe", "meal", "food"]),
            (.fuel, ["加油", "汽油", "柴油", "fuel", "gas", "petrol"]),
            (.software, ["软件", "订阅", "saas", "cloud", "app store", "github", "adobe", "microsoft", "openai"]),
            (.office, ["办公", "文具", "打印", "耗材", "话费", "电信", "移动", "联通", "充值", "电脑", "手机", "macbook", "iphone", "office", "printer"]),
            (.medical, ["医院", "诊所", "药", "医保", "pharmacy", "medical", "clinic", "hospital"]),
            (.home, ["超市", "家居", "家具", "五金", "grocery", "supermarket", "ikea", "costco"])
        ]

        return rules.first { _, keywords in
            keywords.contains { text.contains($0) }
        }?.0 ?? .other
    }

    private static func inferredReimbursementStatus(category: ReceiptCategory, text: String) -> ReimbursementStatus {
        let text = semanticReceiptText(from: text)
        if textContainsAny(["已报销", "reimbursed"], in: text) {
            return .reimbursed
        }

        if textContainsAny([
            "差旅", "商务", "客户", "项目", "公司", "办公", "会议", "出差",
            "话费", "电信", "移动", "联通", "打印", "耗材", "停车", "打车",
            "business", "client", "project", "office", "travel", "meeting"
        ], in: text) {
            return .reimbursable
        }

        switch category {
        case .travel, .fuel, .office, .software:
            return .reimbursable
        case .meals:
            return textContainsAny(["客户", "商务", "会议", "出差", "client", "business", "meeting"], in: text) ? .reimbursable : .notReimbursable
        case .medical, .home, .other:
            return .notReimbursable
        }
    }

    private static func generatedNotes(
        merchant: String,
        category: ReceiptCategory,
        totalText: String,
        currencyCode: String,
        text: String,
        paymentMethod: String,
        lineItems: [ReceiptLineItem]
    ) -> String {
        var parts: [String] = []

        if !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(merchant)
        }

        parts.append(category.localizedName)

        if let total = DecimalParser.parse(totalText) {
            parts.append(total.formatted(.currency(code: currencyCode)))
        }

        if let purpose = inferredPurpose(from: text, category: category) {
            parts.append(purpose)
        }

        if !paymentMethod.isEmpty {
            parts.append(paymentMethod)
        }

        if let firstItem = lineItems.first?.name, !firstItem.isEmpty {
            parts.append("包含 \(firstItem)")
        }

        return parts.joined(separator: " · ")
    }

    private static func inferredPurpose(from text: String, category: ReceiptCategory) -> String? {
        let text = semanticReceiptText(from: text)
        if textContainsAny(["话费", "电信", "移动", "联通", "充值"], in: text) {
            return "通讯费用"
        }
        if textContainsAny(["酒店", "机票", "机场", "打车", "停车", "高铁"], in: text) {
            return "差旅费用"
        }
        if textContainsAny(["办公", "文具", "打印", "耗材"], in: text) {
            return "办公费用"
        }
        if textContainsAny(["订阅", "软件", "saas", "cloud"], in: text) {
            return "软件服务"
        }

        switch category {
        case .meals: return "餐饮费用"
        case .fuel: return "交通能源"
        case .medical: return "医疗费用"
        case .home: return "日常采购"
        default: return nil
        }
    }

    private static func textContainsAny(_ keywords: [String], in text: String) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func semanticReceiptText(from text: String) -> String {
        text
            .replacingOccurrences(of: "打印时间", with: "")
            .replacingOccurrences(of: "打印時間", with: "")
            .replacingOccurrences(of: "打日時間", with: "")
            .replacingOccurrences(of: "打可時日", with: "")
    }
}

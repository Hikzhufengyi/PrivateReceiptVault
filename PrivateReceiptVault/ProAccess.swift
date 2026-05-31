import Foundation

@MainActor
final class ProAccess: ObservableObject {
    static let freeReceiptLimit = 30

    @Published var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: Self.proKey)
        }
    }

    init() {
        isPro = UserDefaults.standard.bool(forKey: Self.proKey)
    }

    func canAddReceipt(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeReceiptLimit
    }

    func unlockFromPurchase() {
        isPro = true
    }

    func unlockForTesting() {
        isPro = true
    }

    func resetForTesting() {
        isPro = false
    }

    private static let proKey = "pro_access_unlocked"
}

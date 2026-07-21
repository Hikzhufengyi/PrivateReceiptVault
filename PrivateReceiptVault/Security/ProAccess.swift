import Foundation

@MainActor
final class ProAccess: ObservableObject {
    static let freeReceiptLimit = 30

    @Published private(set) var isPro = false
    @Published private(set) var hasLifetimeAccess = false
    @Published private(set) var hasActiveSubscription = false

    private var isDebugUnlocked = false

    init() {
        let defaults = UserDefaults.standard
        let legacyUnlocked = defaults.bool(forKey: Self.legacyProKey)
        hasLifetimeAccess = defaults.bool(forKey: Self.lifetimeProKey) || legacyUnlocked
        if legacyUnlocked {
            defaults.set(true, forKey: Self.lifetimeProKey)
            defaults.synchronize()
        }
        updateAccess()
    }

    func canAddReceipt(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeReceiptLimit
    }

    func updateStoreEntitlements(hasLifetime: Bool, hasActiveSubscription: Bool) {
        if hasLifetime {
            self.hasLifetimeAccess = true
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: Self.lifetimeProKey)
            defaults.synchronize()
        }
        self.hasActiveSubscription = hasActiveSubscription
        updateAccess()
    }

    func unlockForTesting() {
        isDebugUnlocked = true
        updateAccess()
    }

    func resetForTesting() {
        isDebugUnlocked = false
        hasActiveSubscription = false
        updateAccess()
    }

    private func updateAccess() {
        isPro = hasLifetimeAccess || hasActiveSubscription || isDebugUnlocked
    }

    private static let legacyProKey = "pro_access_unlocked"
    private static let lifetimeProKey = "pro_access_lifetime_unlocked"
}

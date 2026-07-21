import Foundation
import StoreKit

@MainActor
final class StoreKitService: ObservableObject {
    static let monthlyProductID = "receiptvault.pro.monthly"
    static let yearlyProductID = "receiptvault.pro.yearly"
    static let legacyLifetimeProductID = "receiptvault.pro.lifetime"
    static let subscriptionProductIDs: Set<String> = [monthlyProductID, yearlyProductID]
    static let allProductIDs: Set<String> = subscriptionProductIDs.union([legacyLifetimeProductID])

    @Published private(set) var products: [Product] = []
    @Published var selectedProductID = yearlyProductID
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    private var transactionUpdatesTask: Task<Void, Never>?

    var monthlyProduct: Product? { product(for: Self.monthlyProductID) }
    var yearlyProduct: Product? { product(for: Self.yearlyProductID) }
    var selectedProduct: Product? { product(for: selectedProductID) }

    func start(proAccess: ProAccess) async {
        startObservingTransactions(proAccess: proAccess)
        await loadProducts()
        await refreshEntitlements(proAccess: proAccess)
    }

    func loadProducts() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Array(Self.allProductIDs))
                .filter { Self.subscriptionProductIDs.contains($0.id) }
                .sorted { productRank($0.id) < productRank($1.id) }
            if monthlyProduct == nil || yearlyProduct == nil {
                errorMessage = String(localized: "Subscription options are unavailable. Please try again later.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchaseSelectedProduct(proAccess: ProAccess) async {
        errorMessage = nil
        guard let product = selectedProduct else {
            errorMessage = String(localized: "Subscription options are unavailable. Please try again later.")
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = String(localized: "Purchase could not be verified.")
                    return
                }
                await transaction.finish()
                await refreshEntitlements(proAccess: proAccess)
            case .userCancelled:
                break
            case .pending:
                errorMessage = String(localized: "Purchase is pending approval.")
            @unknown default:
                errorMessage = String(localized: "Unknown purchase result.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases(proAccess: ProAccess) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements(proAccess: proAccess)
            if !proAccess.isPro {
                errorMessage = String(localized: "No active Pro subscription or lifetime purchase was found for this Apple ID.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements(proAccess: ProAccess) async {
        var hasLifetime = false
        var hasActiveSubscription = false
        let now = Date()

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.revocationDate == nil else { continue }

            if transaction.productID == Self.legacyLifetimeProductID {
                hasLifetime = true
            } else if Self.subscriptionProductIDs.contains(transaction.productID),
                      transaction.expirationDate.map({ $0 > now }) ?? true {
                hasActiveSubscription = true
            }
        }

        proAccess.updateStoreEntitlements(
            hasLifetime: hasLifetime,
            hasActiveSubscription: hasActiveSubscription
        )
    }

    private func product(for identifier: String) -> Product? {
        products.first { $0.id == identifier }
    }

    private func productRank(_ identifier: String) -> Int {
        identifier == Self.yearlyProductID ? 0 : 1
    }

    private func startObservingTransactions(proAccess: ProAccess) {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self, weak proAccess] in
            for await update in Transaction.updates {
                guard !Task.isCancelled else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                guard let self, let proAccess else { return }
                await self.refreshEntitlements(proAccess: proAccess)
            }
        }
    }
}

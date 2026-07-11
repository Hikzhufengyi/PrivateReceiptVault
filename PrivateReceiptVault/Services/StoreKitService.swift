import Foundation
import StoreKit

@MainActor
final class StoreKitService: ObservableObject {
    static let proProductID = "receiptvault.pro.lifetime"

    @Published private(set) var product: Product?
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [Self.proProductID]).first
            if product == nil {
                errorMessage = "Product ID \(Self.proProductID) was not found. Check App Store Connect and StoreKit configuration."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(proAccess: ProAccess) async {
        guard let product else {
            errorMessage = "Product is not available yet."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified = verification else {
                    errorMessage = "Purchase could not be verified."
                    return
                }
                proAccess.unlockFromPurchase()
            case .userCancelled:
                errorMessage = "Purchase cancelled."
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                errorMessage = "Unknown purchase result."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases(proAccess: ProAccess) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            var restored = false
            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let transaction) = entitlement,
                   transaction.productID == Self.proProductID {
                    proAccess.unlockFromPurchase()
                    restored = true
                }
            }
            if !restored {
                errorMessage = "No Pro purchase was found for this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

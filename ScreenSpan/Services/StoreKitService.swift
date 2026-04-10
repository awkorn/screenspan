import Foundation
import StoreKit
import SwiftUI

/// Service for managing in-app purchases and subscriptions
@MainActor
class StoreKitService: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var currentSubscriptionStatus: SubscriptionStatus = .free

    /// Load available products from App Store
    func loadProducts() {
        Task {
            do {
                let productIDs = [
                    AppConstants.ProductID.monthlySubscription,
                    AppConstants.ProductID.annualSubscription,
                    AppConstants.ProductID.lifeTimeAccess
                ]
                products = try await Product.products(for: productIDs)
            } catch {
                print("Failed to load products: \(error)")
            }
        }
    }

    /// Purchase a product
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchasedProductIDs.insert(product.id)

                // Update subscription status in AppGroupManager
                currentSubscriptionStatus = .premium
                AppGroupManager.shared.subscriptionStatus = SubscriptionStatus.premium.rawValue
            case .userCancelled:
                print("User cancelled purchase")
            case .pending:
                print("Purchase pending")
            @unknown default:
                print("Unknown purchase result")
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }

    /// Check verified transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.unverifiedTransaction
        case .verified(let safe):
            return safe
        }
    }
}

enum PurchaseError: Error {
    case unverifiedTransaction
}

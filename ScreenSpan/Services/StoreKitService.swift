import Foundation
import StoreKit
import SwiftUI

/// ScreenSpan Pro purchases and entitlement, with StoreKit 2. The verified
/// entitlement is mirrored into the App Group for the blocking extensions.
@MainActor
final class StoreKitService: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed
    }

    enum PurchaseOutcome: Equatable {
        case purchased, pending, cancelled
        case failed(String)
    }

    /// The subscription currently giving access, for Settings.
    struct ActivePlan: Equatable {
        let productID: String
        let isTrial: Bool
        let expirationDate: Date?
        let willAutoRenew: Bool

        var name: String {
            productID == AppConstants.ProductID.annualSubscription ? "Annual" : "Monthly"
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState = LoadState.idle
    @Published private(set) var activePlan: ActivePlan?
    @Published private(set) var isEligibleForTrial = true
    /// Nil until StoreKit has been asked this launch. Blocking is only turned
    /// off after a definitive answer, not on a cold start.
    @Published private(set) var verifiedEntitlement: Bool?

    private var updates: Task<Void, Never>?

    /// Verified entitlement, or the last one recorded before this launch.
    var isPro: Bool { verifiedEntitlement ?? BlockingEntitlement.isActive }

    var annual: Product? { products.first { $0.id == AppConstants.ProductID.annualSubscription } }
    var monthly: Product? { products.first { $0.id == AppConstants.ProductID.monthlySubscription } }

    init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { await refreshEntitlements() }
    }

    deinit { updates?.cancel() }

    func loadProducts() async {
        // A partial list (a product still propagating) is retried next time.
        guard loadState != .loading, products.count < AppConstants.ProductID.all.count else { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: AppConstants.ProductID.all)
            products = AppConstants.ProductID.all.compactMap { id in loaded.first { $0.id == id } }
            if let subscription = products.first?.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
            loadState = products.isEmpty ? .failed : .loaded
        } catch {
            loadState = .failed
        }
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .success(.unverified):
                return .failed("The App Store couldn't verify this purchase. You haven't been charged twice; try Restore Purchases.")
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Syncs with the App Store, which may ask the user to sign in.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isPro
    }

    func refreshEntitlements() async {
        var plan: ActivePlan?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  AppConstants.ProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  (transaction.expirationDate ?? .distantFuture) > Date()
            else { continue }
            plan = ActivePlan(productID: transaction.productID,
                              isTrial: transaction.offerType == .introductory,
                              expirationDate: transaction.expirationDate,
                              willAutoRenew: await Self.willAutoRenew(groupID: transaction.subscriptionGroupID))
        }
        activePlan = plan
        verifiedEntitlement = plan != nil
        let status: SubscriptionStatus = plan.map { $0.isTrial ? .trial : .premium } ?? .free
        AppGroupManager.shared.subscriptionStatus = status.rawValue
    }

    private static func willAutoRenew(groupID: String?) async -> Bool {
        guard let groupID, let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else { return true }
        return statuses.contains {
            guard case .verified(let info) = $0.renewalInfo else { return false }
            return info.willAutoRenew
        }
    }
}

extension Product {
    /// "7-day", "1-month": the free trial length, when this product has one.
    var freeTrialLength: String? {
        freeTrial.map { "\($0.count)-\($0.unit)" }
    }

    /// "7 days", "1 month": the same length, for a sentence.
    var freeTrialDuration: String? {
        freeTrial.map { "\($0.count) \($0.unit)\($0.count == 1 ? "" : "s")" }
    }

    private var freeTrial: (count: Int, unit: String)? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return (period.value, "day")
        case .week: return (period.value * 7, "day")
        case .month: return (period.value, "month")
        case .year: return (period.value, "year")
        @unknown default: return nil
        }
    }

    /// "year" or "month", for "$29.99 per year".
    var periodName: String {
        switch subscription?.subscriptionPeriod.unit {
        case .year: "year"
        case .month: "month"
        case .week: "week"
        case .day: "day"
        default: "period"
        }
    }

    /// The price spread over months, for comparing an annual plan.
    var monthlyEquivalent: String? {
        guard subscription?.subscriptionPeriod.unit == .year else { return nil }
        let perMonth = price / Decimal(12 * (subscription?.subscriptionPeriod.value ?? 1))
        return perMonth.formatted(priceFormatStyle)
    }
}

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var lastError: String?

    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        Task {
            await loadProducts()
            await refreshEntitlements()
            await listenForTransactions()
        }
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductIDs.all)
            products = loaded.sorted(by: { $0.price < $1.price })
        } catch {
            lastError = "Failed to load products: \(error.localizedDescription)"
            products = []
        }
    }

    func refreshEntitlements() async {
        var pro = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProductIDs.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            // For subscriptions, expirationDate is non-nil.
            if (transaction.expirationDate ?? .distantFuture) > Date() {
                pro = true
            }
        }

        isPro = pro
    }

    func purchaseMonthly() async {
        guard let product = products.first(where: { $0.id == ProductIDs.proMonthly }) else {
            lastError = "Monthly product not found. Check Product ID in App Store Connect."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

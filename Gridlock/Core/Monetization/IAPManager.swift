import StoreKit
import os.log

// MARK: - IAP Manager (StoreKit 2)

final class IAPManager: ObservableObject {
    static let shared = IAPManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false

    private var updateListenerTask: Task<Void, Error>?
    private let logger = Logger(subsystem: "com.gridlock.app", category: "IAPManager")

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        do {
            let storeProducts = try await Product.products(for: MonetizationConfig.ProductID.all)
            await MainActor.run {
                self.products = storeProducts.sorted { $0.price < $1.price }
                self.isLoading = false
            }
            logger.info("Loaded \(storeProducts.count) products")
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            logger.info("Purchased: \(product.id)")
            return transaction

        case .userCancelled:
            logger.info("Purchase cancelled by user")
            return nil

        case .pending:
            logger.info("Purchase pending approval")
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        logger.info("Restoring purchases...")
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - Status Checks

    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    var isRemoveAdsActive: Bool {
        isPurchased(MonetizationConfig.ProductID.removeAdsMonthly) ||
        isPurchased(MonetizationConfig.ProductID.removeAdsYearly)
    }

    func isThemePurchased(_ themeProductID: String) -> Bool {
        isPurchased(themeProductID)
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerification(result)
                    await self?.updatePurchasedProducts()
                    await transaction?.finish()
                } catch {
                    self?.logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Update Purchased

    private func updatePurchasedProducts() async {
        var newPurchased = Set<String>()

        // Check subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerification(result)
                if transaction.revocationDate == nil {
                    newPurchased.insert(transaction.productID)
                }
            } catch {
                logger.error("Entitlement verification failed: \(error.localizedDescription)")
            }
        }

        let finalPurchased = newPurchased
        await MainActor.run {
            self.purchasedProductIDs = finalPurchased
            UserProgressManager.shared.removeAdsActive = self.isRemoveAdsActive
        }

        logger.info("Updated purchases: \(finalPurchased)")
    }

    // MARK: - Product Helpers

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func subscriptionProducts() -> [Product] {
        products.filter { MonetizationConfig.ProductID.allSubscriptions.contains($0.id) }
    }

    func themeProducts() -> [Product] {
        products.filter { MonetizationConfig.ProductID.allThemes.contains($0.id) }
    }
}

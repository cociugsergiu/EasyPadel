import Foundation
import StoreKit

/// Handles the single "Full Access" unlock via StoreKit 2. Shared between the
/// iPhone and Watch targets — each device checks its own entitlements
/// independently (StoreKit keeps them in sync per Apple ID across a person's
/// devices, so there's no need to relay purchase state over
/// WatchConnectivity the way match state is).
@MainActor
final class PurchaseManager: ObservableObject {
    static let fullAccessProductID = "com.easypadel.app.fullaccess"

    @Published private(set) var isUnlocked = false
    @Published private(set) var product: Product?
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    // Explicitly nonisolated so this can be constructed synchronously from
    // non-main-actor contexts (MatchStore's own stored-property
    // initializer isn't main-actor-isolated) — safe because everything the
    // init body does either just stores initial state or hops onto the
    // main actor itself via `await` inside its Task closures.
    nonisolated init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await self.loadProduct() }
        Task { await self.refreshEntitlements() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.fullAccessProductID])
            product = products.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            await handle(result)
        }
    }

    func purchase() async {
        errorMessage = nil
        guard let product else {
            errorMessage = "Full Access isn't available right now — check your connection and try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        errorMessage = nil
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isUnlocked {
                errorMessage = "No previous purchase found for this Apple Account."
            }
        } catch {
            // AppStore.sync() talks to the real App Store, not the local
            // StoreKit Testing config — if you're testing without a real
            // com.easypadel.app.fullaccess product in App Store Connect yet,
            // this is expected to fail unless the app was launched from
            // Xcode's Run button (not a standalone reinstall), which is what
            // attaches Configuration.storekit for the session.
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.fullAccessProductID && transaction.revocationDate == nil {
            isUnlocked = true
        }
        await transaction.finish()
    }
}

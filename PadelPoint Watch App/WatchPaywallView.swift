import SwiftUI

/// Watch counterpart to the iPhone's PaywallView — same purchase, same
/// `PurchaseManager`, condensed for the small screen. Shown when the free
/// match allowance runs out and the hold-to-reset gesture would otherwise
/// start a new match (see `MatchStore.beginNewMatch`).
struct WatchPaywallView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss

    private var priceText: String {
        store.purchases.product?.displayPrice ?? "$0.99"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 4)

                Text("\(MatchStore.freeMatchLimit) free matches used")
                    .font(.system(size: 14, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Unlock EasyPadel once, for good.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Button {
                    Task { await store.purchases.purchase() }
                } label: {
                    if store.purchases.isPurchasing {
                        ProgressView()
                    } else {
                        Text("Unlock — \(priceText)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .tint(Theme.gold)
                .disabled(store.purchases.isPurchasing)

                Button {
                    Task { await store.purchases.restore() }
                } label: {
                    Text("Restore")
                        .font(.system(size: 12))
                }

                Button("Not Now") { dismiss() }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))

                if let message = store.purchases.errorMessage {
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.teamA)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
        }
        .onChange(of: store.purchases.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }
}

#Preview {
    WatchPaywallView().environmentObject(MatchStore())
}

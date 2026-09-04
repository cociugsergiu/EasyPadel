import SwiftUI

/// Shown when the free match allowance runs out. Presented as a sheet from
/// wherever a new match would otherwise start (see `MatchStore.beginNewMatch`),
/// so declining it just closes the sheet — the match in progress, history,
/// and settings are all untouched either way.
struct PaywallView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss

    private var priceText: String {
        store.purchases.product?.displayPrice ?? "$0.99"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.teamA, Theme.teamB],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 6)

                    Text("You've played your \(MatchStore.freeMatchLimit) free matches")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    Text("Unlock EasyPadel once, for good — no subscription, and it covers both your iPhone and Watch.")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        Task { await store.purchases.purchase() }
                    } label: {
                        HStack {
                            if store.purchases.isPurchasing {
                                ProgressView().tint(.black)
                            } else {
                                Text("Unlock Full Access — \(priceText)")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.gold, in: Capsule())
                        .foregroundStyle(.black)
                    }
                    .disabled(store.purchases.isPurchasing)

                    Button {
                        Task { await store.purchases.restore() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let message = store.purchases.errorMessage {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.teamA)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.purchases.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }
}

#Preview {
    PaywallView().environmentObject(MatchStore())
}

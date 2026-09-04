import SwiftUI

/// A minimal, "fancy but quiet" stats sheet: lifetime matches played and a
/// progress bar that runs through the three theme-unlock checkpoints
/// (bronze/silver/gold), plus a discreet, confirmed reset for the counter.
struct MatchesPlayedView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReset = false

    private let checkpoints = [5, 10, 20]
    private let checkpointColors: [Color] = [
        Color(red: 0.72, green: 0.45, blue: 0.22),
        Color(red: 0.76, green: 0.79, blue: 0.82),
        Color(red: 0.85, green: 0.66, blue: 0.18)
    ]

    var body: some View {
        let played = store.state.matchesPlayed
        let cap = Double(checkpoints.last ?? 1)
        let progress = min(Double(played) / cap, 1)

        NavigationStack {
            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 4) {
                    Text("\(played)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(played == 1 ? "MATCH PLAYED" : "MATCHES PLAYED")
                        .silverLabel(size: 12, tracking: 3)
                }

                VStack(spacing: 14) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.12))
                                .frame(height: 8)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.gold.opacity(0.6), Theme.gold],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 8)

                            ForEach(Array(checkpoints.enumerated()), id: \.offset) { i, milestone in
                                let x = geo.size.width * (Double(milestone) / cap)
                                Circle()
                                    .fill(played >= milestone ? checkpointColors[i] : Color.white.opacity(0.25))
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                                    .position(x: x, y: 4)
                            }
                        }
                    }
                    .frame(height: 14)

                    HStack {
                        ForEach(Array(checkpoints.enumerated()), id: \.offset) { i, milestone in
                            if i > 0 { Spacer() }
                            VStack(spacing: 2) {
                                Text("\(milestone)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(played >= milestone ? checkpointColors[i] : .white.opacity(0.4))
                                Text(themeName(i))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)

                Spacer()

                Button {
                    confirmingReset = true
                } label: {
                    Text("Reset Progress")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset matches played back to 0? Any color styles you unlocked will lock again.",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    store.resetMatchesPlayed()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    private func themeName(_ index: Int) -> String {
        ["BRONZE", "SILVER", "GOLD"][index]
    }
}

#Preview {
    MatchesPlayedView().environmentObject(MatchStore())
}

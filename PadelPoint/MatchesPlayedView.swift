import SwiftUI

/// A minimal, "fancy but quiet" stats sheet: lifetime matches played and a
/// progress bar that runs through the three theme-unlock checkpoints
/// (bronze/silver/gold), plus a discreet, confirmed reset for the counter.
struct MatchesPlayedView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingReset = false

    // Drives the "fill up, then pop each checkpoint it passes" reveal that
    // plays once each time this sheet appears — see `animateReveal`.
    @State private var animatedProgress: CGFloat = 0
    @State private var revealedCheckpoints: Set<Int> = []
    @State private var checkpointScale: [Int: CGFloat] = [:]
    @State private var revealToken = UUID()

    private let checkpoints = [5, 10, 20]
    private let checkpointColors: [Color] = [
        Color(red: 0.72, green: 0.45, blue: 0.22),
        Color(red: 0.76, green: 0.79, blue: 0.82),
        Color(red: 0.85, green: 0.66, blue: 0.18)
    ]
    private let fillDuration: Double = 1.1

    var body: some View {
        let played = store.state.matchesPlayed
        let cap = Double(checkpoints.last ?? 1)
        let progress = min(Double(played) / cap, 1)

        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("\(played)")
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(played == 1 ? "MATCH PLAYED" : "MATCHES PLAYED")
                        .silverLabel(size: 12, tracking: 3)
                }
                .padding(.top, 4)

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
                                .frame(width: geo.size.width * animatedProgress, height: 8)

                            ForEach(Array(checkpoints.enumerated()), id: \.offset) { i, milestone in
                                let x = geo.size.width * (Double(milestone) / cap)
                                Circle()
                                    .fill(revealedCheckpoints.contains(i) ? checkpointColors[i] : Color.white.opacity(0.25))
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                                    .scaleEffect(checkpointScale[i] ?? 1)
                                    // Centered on the bar's own centerline
                                    // (geo.size.height/2), not a hardcoded
                                    // value that assumed a taller container.
                                    .position(x: x, y: geo.size.height / 2)
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
                                    .foregroundStyle(revealedCheckpoints.contains(i) ? checkpointColors[i] : .white.opacity(0.4))
                                Text(themeName(i))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 0)

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
            .padding(.top, 20)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear {
            animateReveal(played: played, cap: cap, progress: progress)
        }
    }

    /// Fills the bar from empty up to the real progress, popping each
    /// checkpoint dot at the moment the fill actually passes it (derived
    /// from `fillDuration` using linear easing, so "time elapsed" maps
    /// directly to "fraction filled" — no guessing at an eased curve).
    private func animateReveal(played: Int, cap: Double, progress: Double) {
        // SwiftUI can reuse this view's @State across dismiss/re-present
        // rather than resetting it — without this, a second viewing could
        // start from wherever the last animation left off (e.g. already at
        // match 5's position), so the fill only visibly moves through the
        // last few matches instead of the whole 0-to-current range. The
        // token additionally guards against a stale scheduled pop from a
        // previous, since-dismissed presentation firing into this one.
        let token = UUID()
        revealToken = token
        animatedProgress = 0
        revealedCheckpoints = []
        checkpointScale = [:]

        guard progress > 0 else { return }

        guard !reduceMotion else {
            animatedProgress = CGFloat(progress)
            revealedCheckpoints = Set(checkpoints.indices.filter { played >= checkpoints[$0] })
            return
        }

        withAnimation(.linear(duration: fillDuration)) {
            animatedProgress = CGFloat(progress)
        }

        for (i, milestone) in checkpoints.enumerated() where played >= milestone {
            let passTime = fillDuration * (Double(milestone) / cap) / progress
            DispatchQueue.main.asyncAfter(deadline: .now() + passTime) {
                guard revealToken == token else { return }
                popCheckpoint(i)
            }
        }
    }

    /// A quick snap past full size, then a springy settle back to it —
    /// scheduled explicitly in two stages (rather than composed via
    /// `Animation.delay`) so the two stages can't visually overlap.
    private func popCheckpoint(_ i: Int) {
        let token = revealToken
        withAnimation(.easeOut(duration: 0.12)) {
            revealedCheckpoints.insert(i)
            checkpointScale[i] = 1.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard revealToken == token else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                checkpointScale[i] = 1.0
            }
        }
    }

    private func themeName(_ index: Int) -> String {
        ["BRONZE", "SILVER", "GOLD"][index]
    }
}

#Preview {
    MatchesPlayedView().environmentObject(MatchStore())
}

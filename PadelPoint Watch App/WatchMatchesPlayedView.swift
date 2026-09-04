import SwiftUI

/// Compact watch version of the matches-played stat: a rounded activity-ring
/// style progress indicator running through the three unlock checkpoints.
struct WatchMatchesPlayedView: View {
    @EnvironmentObject private var store: MatchStore
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

        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 8, lineCap: .round))

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [Theme.gold.opacity(0.6), Theme.gold], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    ForEach(Array(checkpoints.enumerated()), id: \.offset) { i, milestone in
                        let angle = Angle(degrees: -90 + 360 * (Double(milestone) / cap))
                        Circle()
                            .fill(played >= milestone ? checkpointColors[i] : Color.white.opacity(0.25))
                            .frame(width: 10, height: 10)
                            .offset(x: cos(angle.radians) * 44, y: sin(angle.radians) * 44)
                    }

                    VStack(spacing: 0) {
                        Text("\(played)")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("MATCHES")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 110, height: 110)
                .padding(.top, 6)

                HStack(spacing: 10) {
                    ForEach(Array(checkpoints.enumerated()), id: \.offset) { i, milestone in
                        VStack(spacing: 1) {
                            Text("\(milestone)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(played >= milestone ? checkpointColors[i] : .white.opacity(0.4))
                            Text(["BRONZE", "SILVER", "GOLD"][i])
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }

                Button {
                    confirmingReset = true
                } label: {
                    Text("Reset Progress")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Progress")
        .confirmationDialog(
            "Reset matches played? Unlocked styles will lock again.",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                store.resetMatchesPlayed()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        WatchMatchesPlayedView().environmentObject(MatchStore())
    }
}

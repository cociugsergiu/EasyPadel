import SwiftUI

/// A full-width tap zone for one team. Tapping anywhere in the zone scores a
/// point for that team, with a soft haptic + scale/flash effect.
struct TeamZone: View {
    let team: Team
    /// Which physical half of the screen this zone occupies — decoupled from
    /// team identity so the gradient direction (richer color toward the
    /// center divider, more muted toward the outer edge) stays correct
    /// regardless of which team is on top.
    let isTop: Bool

    @EnvironmentObject private var store: MatchStore
    @AppStorage("showLabels") private var showLabels = true
    @State private var pulse = false
    @State private var flash = false

    var body: some View {
        let state = store.state
        let color = store.currentTheme.color(for: team)

        ZStack {
            LinearGradient(
                colors: [color.opacity(0.55), color.opacity(0.85)],
                startPoint: isTop ? .top : .bottom,
                endPoint: isTop ? .bottom : .top
            )

            Color.white.opacity(flash ? 0.18 : 0)

            VStack(spacing: 6) {
                Text(state.name(for: team))
                    .textCase(.uppercase)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.75))

                Text(state.pointDisplay(for: team))
                    .font(.system(size: 104, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .engraved()
                    .contentTransition(.numericText())
                    .id(state.pointDisplay(for: team) + String(state.isTiebreak))

                if showLabels {
                    Text("POINTS")
                        .silverLabel(size: 12, tracking: 1.5)
                }

                if state.isDeuce {
                    Text("DEUCE")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                } else if state.servingTeam == team && !state.isTiebreak && state.winner == nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.gold)
                            .frame(width: 6, height: 6)
                        if showLabels {
                            Text("SERVING")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.gold.opacity(0.85))
                        }
                    }
                }
            }
            .scaleEffect(pulse ? 1.06 : 1.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard state.winner == nil else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                store.addPoint(for: team)
                pulse = true
                flash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeOut(duration: 0.25)) {
                    pulse = false
                    flash = false
                }
            }
        }
    }
}

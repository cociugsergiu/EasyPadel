import SwiftUI

/// Landscape layout: exaggerated, edge-to-edge digits for the current point
/// score (readable from across a court), scaled off screen height so it looks
/// right on everything from an iPhone SE to an iPad Pro. Every 8 seconds an
/// info screen (sets, games, serve) fades in for ~3 seconds, then fades back
/// out to the live point score.
struct LandscapeScoreView: View {
    @EnvironmentObject private var store: MatchStore
    @AppStorage("showLabels") private var showLabels = true
    @AppStorage("landscapeInfoStyle") private var infoStyleRaw = LandscapeInfoStyle.badge.rawValue
    @Binding var showSettings: Bool
    @Binding var showMatchesPlayed: Bool
    @Binding var showHistory: Bool
    @State private var showInfo = false

    private var infoStyle: LandscapeInfoStyle {
        LandscapeInfoStyle(rawValue: infoStyleRaw) ?? .badge
    }

    var body: some View {
        let state = store.state
        let theme = store.currentTheme

        GeometryReader { geo in
            ZStack {
                Theme.background
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    pointHalf(.a, state, theme: theme, geo: geo)
                    pointHalf(.b, state, theme: theme, geo: geo)
                }
                .ignoresSafeArea()
                .allowsHitTesting(!(infoStyle == .flash && showInfo))
                .opacity(infoStyle == .flash && showInfo ? 0 : 1)

                if infoStyle == .flash {
                    infoOverlay(state, theme: theme, geo: geo)
                        .ignoresSafeArea()
                        .opacity(showInfo ? 1 : 0)
                        .allowsHitTesting(false)
                } else {
                    setsBadge(state, theme: theme)
                        .padding(.top, 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                }

                VStack {
                    // Fixed-size frames (rather than the old .padding(16),
                    // which made both the tap-target size AND the gap
                    // between icons, so it couldn't set either
                    // independently) at Apple's 44pt minimum tap target,
                    // with a tight explicit spacing between them — also
                    // gives HoldToResetButton (a bare 34pt circle) the same
                    // footprint as the plain icon buttons, instead of it
                    // reading visibly taller than the rest of the row.
                    HStack(spacing: 2) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(width: 44, height: 44)
                        Button {
                            showMatchesPlayed = true
                        } label: {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(width: 44, height: 44)
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            store.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(store.canUndo ? 0.55 : 0.2))
                        }
                        .frame(width: 44, height: 44)
                        .disabled(!store.canUndo)
                        HoldToResetButton {
                            store.resetForHoldGesture()
                        }
                        .frame(width: 44, height: 44)
                        Button {
                            store.beginNewMatch(withCountdown: true)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(width: 44, height: 44)
                    }
                    // On top of each button's own tap-target size — this is
                    // what actually keeps the icons clear of the physical
                    // screen edge (rounded corners, accidental grip
                    // touches), since the whole overlay ignores the safe
                    // area to let the score halves reach edge-to-edge.
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    Spacer()
                    HistoryButton { showHistory = true }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            guard infoStyle == .flash, store.state.winner == nil else { return }
            withAnimation(.easeInOut(duration: 0.5)) { showInfo = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.5)) { showInfo = false }
            }
        }
    }

    @ViewBuilder
    private func setsBadge(_ state: MatchState, theme: TeamTheme) -> some View {
        VStack(spacing: 4) {
            badgeRow(label: "SETS", a: state.setsA, b: state.setsB, aColor: .white.opacity(0.95), bColor: .white.opacity(0.95), size: 19)

            if state.isTiebreak {
                badgeRow(label: "TIEBREAK", a: state.tiebreakA, b: state.tiebreakB, aColor: theme.color(for: .a), bColor: theme.color(for: .b), size: 15)
            } else {
                badgeRow(label: "GAMES", a: state.gamesA, b: state.gamesB, aColor: theme.color(for: .a), bColor: theme.color(for: .b), size: 15)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }

    private func badgeRow(label: String, a: Int, b: Int, aColor: Color, bColor: Color, size: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text("\(a)")
                .foregroundStyle(aColor)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.6))
            Text("\(b)")
                .foregroundStyle(bColor)
        }
        .font(.system(size: size, weight: .heavy, design: .rounded))
    }

    @ViewBuilder
    private func pointHalf(_ team: Team, _ state: MatchState, theme: TeamTheme, geo: GeometryProxy) -> some View {
        let color = theme.color(for: team)

        ZStack {
            LinearGradient(
                colors: [color.opacity(0.55), color.opacity(0.85)],
                startPoint: team == .a ? .trailing : .leading,
                endPoint: team == .a ? .leading : .trailing
            )

            VStack(spacing: geo.size.height * 0.02) {
                if showLabels {
                    Text(state.name(for: team))
                        .textCase(.uppercase)
                        .font(.system(size: min(geo.size.height * 0.055, 22), weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text(state.pointDisplay(for: team))
                    .font(.system(size: geo.size.height * 0.62, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    // Fixed height regardless of how much minimumScaleFactor
                    // shrinks a wider value (e.g. "40"/"AD" vs "0") to fit —
                    // without this, the two halves' content stacks end up
                    // different total heights and, since each VStack centers
                    // independently, the name label above ends up sitting at
                    // a different height on each side.
                    .frame(height: geo.size.height * 0.62)
                    .foregroundStyle(.white)
                    .engraved()
                    .contentTransition(.numericText())

                // Both possible views are always present (just opacity-
                // toggled) rather than conditionally included/excluded —
                // wrapping a conditional in Group and forcing a .frame
                // height on it did NOT reliably give both teams' halves the
                // same reserved height in practice (Team A, with a visible
                // "SERVING" row, sat measurably higher than Team B's empty
                // one). Rendering the exact same view structure on both
                // sides removes any ambiguity about it.
                ZStack {
                    Text("DEUCE")
                        .font(.system(size: min(geo.size.height * 0.05, 20), weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.75))
                        .opacity(state.isDeuce ? 1 : 0)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.gold)
                            .frame(width: 10, height: 10)
                        if showLabels {
                            Text("SERVING")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(Theme.gold.opacity(0.9))
                        }
                    }
                    .opacity(!state.isDeuce && state.servingTeam == team && !state.isTiebreak && state.winner == nil ? 1 : 0)
                }
                .frame(height: min(geo.size.height * 0.06, 24))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard state.winner == nil else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            store.addPoint(for: team)
        }
    }

    @ViewBuilder
    private func infoOverlay(_ state: MatchState, theme: TeamTheme, geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.94)

            HStack(spacing: 0) {
                infoColumn(.a, state, theme: theme, geo: geo)
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1)
                infoColumn(.b, state, theme: theme, geo: geo)
            }
            .padding(.vertical, geo.size.height * 0.08)
        }
    }

    @ViewBuilder
    private func infoColumn(_ team: Team, _ state: MatchState, theme: TeamTheme, geo: GeometryProxy) -> some View {
        VStack(spacing: geo.size.height * 0.04) {
            statBlock(
                label: "SETS",
                value: state.sets(for: team),
                color: .white.opacity(0.9),
                geo: geo
            )

            if state.isTiebreak {
                statBlock(
                    label: "TIEBREAK",
                    value: state.tiebreakPoints(for: team),
                    color: theme.color(for: team),
                    geo: geo
                )
            } else {
                statBlock(
                    label: "GAMES",
                    value: state.games(for: team),
                    color: theme.color(for: team),
                    geo: geo
                )
            }

            if !state.completedSets.isEmpty {
                Text(state.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ·  "))
                    .silverLabel(size: min(geo.size.height * 0.03, 13), tracking: 0.5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statBlock(label: String, value: Int, color: Color, geo: GeometryProxy) -> some View {
        VStack(spacing: geo.size.height * 0.01) {
            if showLabels {
                Text(label)
                    .silverLabel(size: min(geo.size.height * 0.04, 16), tracking: 3)
            }
            Text("\(value)")
                .font(.system(size: geo.size.height * 0.22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

#Preview(traits: .landscapeRight) {
    ContentView()
        .environmentObject(MatchStore())
}

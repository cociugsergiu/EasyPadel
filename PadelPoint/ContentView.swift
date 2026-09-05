import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var showSettings = false
    @State private var showMatchesPlayed = false
    @State private var showHistory = false
    @State private var showStylePicker = false
    @State private var showSpectator = false

    var body: some View {
        let state = store.state

        GeometryReader { geo in
            ZStack {
                Theme.background.ignoresSafeArea()

                if geo.size.width > geo.size.height {
                    LandscapeScoreView(
                        showSettings: $showSettings,
                        showMatchesPlayed: $showMatchesPlayed,
                        showHistory: $showHistory
                    )
                    .ignoresSafeArea()
                } else {
                    ZStack(alignment: .bottom) {
                        VStack(spacing: 0) {
                            TeamZone(team: .a, isTop: true)

                            CenterBar(showSettings: $showSettings, showMatchesPlayed: $showMatchesPlayed)

                            TeamZone(team: .b, isTop: false)
                        }
                        .ignoresSafeArea(edges: .bottom)

                        HistoryButton { showHistory = true }
                            .padding(.bottom, 10)
                    }
                }

                CourtLighting()

                if let winner = state.winner {
                    WinnerOverlay(winner: winner, name: state.name(for: winner), theme: store.currentTheme) {
                        store.beginNewMatch(withCountdown: false)
                    }
                }

                if let deadline = state.newMatchCountdownDeadline {
                    NewMatchCountdownOverlay(deadline: deadline)
                }

                if showStylePicker {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showStylePicker = false
                            }
                        }

                    BackgroundStylePicker(isPresented: $showStylePicker)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                }

                if store.multipeer.isViewing {
                    SpectatingBanner {
                        store.leaveSpectating()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .onAppear {
            store.refreshFromPairedDevice()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(showStylePicker: $showStylePicker, showSpectator: $showSpectator)
                .environmentObject(store)
        }
        .sheet(isPresented: $showHistory) {
            MatchHistoryView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showMatchesPlayed) {
            MatchesPlayedView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showPaywall) {
            PaywallView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showSpectator) {
            SpectatorView()
                .environmentObject(store)
        }
    }
}

/// Persistent strip while watching someone else's match — the whole score
/// screen behind it is a live, read-only mirror, so this is the one control
/// that stays active: leaving hands the screen back to whatever match (or
/// lack of one) this device had going before it started watching.
private struct SpectatingBanner: View {
    let onLeave: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 12, weight: .semibold))
            Text("SPECTATING")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.5)
            Spacer()
            Button(action: onLeave) {
                Text("Leave")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.gold, in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.black.opacity(0.75))
        .frame(maxWidth: .infinity)
    }
}

/// Small, discreet floating button — used for match history, which
/// deliberately doesn't live in the center bar with the rest of the
/// controls, since it's a "look something up" action rather than an
/// in-the-moment scoring one.
struct HistoryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.32), in: Circle())
        }
    }
}

private struct CenterBar: View {
    @EnvironmentObject private var store: MatchStore
    @AppStorage("showLabels") private var showLabels = true
    @Binding var showSettings: Bool
    @Binding var showMatchesPlayed: Bool

    var body: some View {
        let state = store.state
        let theme = store.currentTheme

        HStack {
            HStack(spacing: 4) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 28, height: 34)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLabels.toggle()
                    }
                } label: {
                    Image(systemName: showLabels ? "tag.fill" : "tag")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 28, height: 34)

                Button {
                    showMatchesPlayed = true
                } label: {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 28, height: 34)
            }

            Spacer()

            VStack(spacing: 3) {
                statRow(label: "SETS", a: state.setsA, b: state.setsB, colored: false, theme: theme)

                if state.isTiebreak {
                    statRow(label: "TIEBREAK", a: state.tiebreakA, b: state.tiebreakB, colored: true, theme: theme)
                } else {
                    statRow(label: "GAMES", a: state.gamesA, b: state.gamesB, colored: true, theme: theme)
                }

                if showLabels && !state.completedSets.isEmpty {
                    Text(state.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ·  "))
                        .silverLabel(size: 11, tracking: 0.5)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(store.canUndo ? 0.7 : 0.2))
                }
                .frame(width: 26, height: 34)
                .disabled(!store.canUndo)

                HoldToResetButton {
                    store.resetForHoldGesture()
                }

                Button {
                    store.beginNewMatch(withCountdown: true)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 26, height: 34)
            }
            .disabled(store.multipeer.isViewing)
            .opacity(store.multipeer.isViewing ? 0.3 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(.black.opacity(0.55))
    }

    private func statRow(label: String, a: Int, b: Int, colored: Bool, theme: TeamTheme) -> some View {
        HStack(spacing: 8) {
            Text("\(a)")
                .foregroundStyle(colored ? theme.color(for: .a) : .white.opacity(0.9))
                .frame(minWidth: 16)
            if showLabels {
                Text(label)
                    .silverLabel(size: 11, tracking: 1.5)
            }
            Text("\(b)")
                .foregroundStyle(colored ? theme.color(for: .b) : .white.opacity(0.9))
                .frame(minWidth: 16)
        }
        .font(.system(size: 18, weight: .bold, design: .rounded))
    }
}

private struct WinnerOverlay: View {
    let winner: Team
    let name: String
    let theme: TeamTheme
    let onNewMatch: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("\(name) WINS")
                    .textCase(.uppercase)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.color(for: winner))

                Button(action: onNewMatch) {
                    Text("New Match")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Theme.gold, in: Capsule())
                }
            }
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                appear = true
            }
        }
    }
}

/// Confirms the "start a brand new match" action with a 3-2-1 countdown,
/// cancellable at any point. Driven by a synced deadline (`state.newMatch-
/// CountdownDeadline`), so pressing the button on one device shows this
/// same overlay, counting down together, on the paired device almost
/// instantly. Sized off the smaller screen dimension so it scales cleanly
/// across portrait, landscape, and iPad rather than assuming one fixed size.
private struct NewMatchCountdownOverlay: View {
    @EnvironmentObject private var store: MatchStore
    let deadline: Date

    var body: some View {
        GeometryReader { geo in
            let base = min(geo.size.width, geo.size.height)

            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()

                VStack(spacing: base * 0.09) {
                    Text("NEW MATCH STARTING")
                        .font(.system(size: max(base * 0.038, 12), weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.55))

                    CountdownDigit(deadline: deadline, fontSize: base * 0.28) {
                        store.resetMatch()
                    }

                    Button {
                        store.cancelNewMatchCountdown()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: max(base * 0.045, 14), weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, base * 0.07)
                            .padding(.vertical, base * 0.028)
                            .background(.white.opacity(0.14), in: Capsule())
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView().environmentObject(MatchStore())
}

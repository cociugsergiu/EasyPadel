import SwiftUI
import WatchKit

/// Whole-screen gesture surface: tap = point for Team A, double tap = point for
/// Team B, hold = reset. Designed to be operated without looking, using
/// distinct haptics per action, since players are mid-rally.
struct WatchContentView: View {
    @EnvironmentObject private var store: MatchStore
    @StateObject private var workoutManager = WorkoutManager()
    @State private var showMatchesPlayed = false
    @State private var showHistory = false

    @State private var isHolding = false
    @State private var holdProgress: CGFloat = 0
    @State private var lastScored: Team?
    @State private var pendingSingleTap: DispatchWorkItem?
    @State private var showUndoFlash = false

    private let holdDuration: Double = 1.0
    private let doubleTapWindow: Double = 0.3

    var body: some View {
        let state = store.state
        let theme = store.currentTheme

        NavigationStack {
            ZStack {
                HStack(spacing: 0) {
                    theme.color(for: .a).opacity(0.9)
                    theme.color(for: .b).opacity(0.9)
                }
                .ignoresSafeArea()

                CourtLighting(intensity: 0.7)

                VStack(spacing: 2) {
                    setsRow(state, theme: theme)

                    Spacer(minLength: 0)

                    HStack(spacing: 0) {
                        pointColumn(.a, state)
                        Text(state.isTiebreak ? ":" : "-")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                        pointColumn(.b, state)
                    }

                    Spacer(minLength: 0)

                    gamesRow(state)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)

                if isHolding {
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(Theme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(8)
                        .animation(.linear(duration: holdDuration), value: holdProgress)
                }

                if let winner = state.winner {
                    winnerOverlay(winner, name: state.name(for: winner), theme: theme)
                }

                if showUndoFlash {
                    Text("UNDO")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.75), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                if let deadline = state.newMatchCountdownDeadline {
                    ZStack {
                        Color.black.opacity(0.88).ignoresSafeArea()
                        VStack(spacing: 8) {
                            Text("NEW MATCH")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.55))
                            CountdownDigit(deadline: deadline, fontSize: 44) {
                                store.resetMatch()
                            }
                            Text("Tap to Cancel")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.cancelNewMatchCountdown()
                    }
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 50) {
                guard store.state.newMatchCountdownDeadline == nil else { return }
                WKInterfaceDevice.current().play(.retry)
                store.resetForHoldGesture()
            } onPressingChanged: { pressing in
                isHolding = pressing
            }
            .onTapGesture {
                handleTap()
            }
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard value.translation.width < -30,
                              abs(value.translation.height) < 40 else { return }
                        performUndo()
                    }
            )
            .onChange(of: isHolding) { _, holding in
                holdProgress = holding ? 1 : 0
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMatchesPlayed = true
                    } label: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13))
                    }
                }
            }
            .navigationDestination(isPresented: $showMatchesPlayed) {
                WatchMatchesPlayedView()
            }
            .navigationDestination(isPresented: $showHistory) {
                WatchMatchHistoryView()
            }
        }
        .onAppear {
            store.refreshFromPairedDevice()
            workoutManager.requestAuthorization()
            if state.isInProgress {
                workoutManager.startWorkout()
            }
        }
        .onChange(of: store.state) { oldValue, newValue in
            if !oldValue.isInProgress && newValue.isInProgress {
                workoutManager.startWorkout()
            } else if oldValue.isInProgress && !newValue.isInProgress {
                workoutManager.endWorkout()
            }
        }
    }

    // MARK: Rows

    private func setsRow(_ state: MatchState, theme: TeamTheme) -> some View {
        HStack(spacing: 6) {
            Text("\(state.setsA)")
                .foregroundStyle(.white)
            if state.isTiebreak {
                Text("TB")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.gold)
            } else if state.goldenPoint {
                Text("GP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text("\(state.setsB)")
                .foregroundStyle(.white)
        }
        .font(.system(size: 13, weight: .heavy, design: .rounded))
        .shadow(color: .black.opacity(0.5), radius: 1.5, x: 0, y: 1)
    }

    private func pointColumn(_ team: Team, _ state: MatchState) -> some View {
        Text(state.pointDisplay(for: team))
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .engraved()
            .frame(maxWidth: .infinity)
            .contentTransition(.numericText())
            .scaleEffect(lastScored == team ? 1.15 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: lastScored)
    }

    private func gamesRow(_ state: MatchState) -> some View {
        Text("\(state.gamesA)  GAMES  \(state.gamesB)")
            .font(.system(size: 12, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.white.opacity(0.9))
            .shadow(color: .black.opacity(0.5), radius: 1.5, x: 0, y: 1)
    }

    private func winnerOverlay(_ winner: Team, name: String, theme: TeamTheme) -> some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("\(name)\nWINS")
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.color(for: winner))
                Text("Hold to reset")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: Gestures

    /// Single tap scores Team A; a second tap arriving within the double-tap
    /// window upgrades it to a Team B point instead. Kept as a manual timer
    /// rather than a composed `TapGesture(count:2)` — nesting that with the
    /// long-press reset gesture via `.exclusively(before:)` is unreliable on
    /// watchOS and can swallow taps entirely. `.onLongPressGesture` and
    /// `.onTapGesture` as two independent modifiers (used above) don't have
    /// that problem: a long press never fires the tap, and a quick tap never
    /// triggers the long press.
    private func handleTap() {
        guard store.state.winner == nil, store.state.newMatchCountdownDeadline == nil else { return }

        if let pending = pendingSingleTap {
            pending.cancel()
            pendingSingleTap = nil
            score(.b)
            return
        }

        let work = DispatchWorkItem { [self] in
            score(.a)
            pendingSingleTap = nil
        }
        pendingSingleTap = work
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapWindow, execute: work)
    }

    private func score(_ team: Team) {
        guard store.state.winner == nil else { return }
        WKInterfaceDevice.current().play(team == .a ? .click : .directionUp)
        store.addPoint(for: team)
        lastScored = team
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            lastScored = nil
        }
    }

    /// Swipe left to undo the last accidental tap — easy to trigger by
    /// mistake on a screen this small, so this is the quick fix without
    /// reaching for the phone.
    private func performUndo() {
        guard store.canUndo, store.state.newMatchCountdownDeadline == nil else { return }
        WKInterfaceDevice.current().play(.navigationLeftTurn)
        store.undo()
        withAnimation(.easeOut(duration: 0.15)) { showUndoFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.3)) { showUndoFlash = false }
        }
    }
}

#Preview {
    WatchContentView().environmentObject(MatchStore())
}

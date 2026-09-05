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
    @State private var holdTimer: Timer?
    @State private var holdFired = false
    @State private var touchActive = false

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
            .gesture(scoringGesture)
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
            .sheet(isPresented: $store.showPaywall) {
                WatchPaywallView()
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

    /// Tap, double-tap, hold, and swipe-left-to-undo all handled by one
    /// `DragGesture(minimumDistance: 0)` instead of composing separate
    /// `.onLongPressGesture`/`.onTapGesture`/`.gesture(DragGesture)`
    /// modifiers on the same view. That composed approach is what an
    /// earlier version of this file used, and it does work on some
    /// watchOS builds — but it's arbitration between multiple independent
    /// gesture recognizers on one view, and that arbitration isn't
    /// guaranteed identical across every watchOS version/device: it's been
    /// confirmed, on at least one real device on watchOS 10.6.2, that the
    /// long-press recognizer fires correctly but then never releases the
    /// touch stream back to the tap recognizer, so taps and double-taps
    /// silently never register at all. A single recognizer has nothing to
    /// arbitrate with, which is why this is the more robust shape: touch-
    /// down starts a hold timer (and the progress ring); if it's released
    /// before the timer fires, the release's own translation decides
    /// whether it reads as a tap or a left swipe.
    private var scoringGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !touchActive else { return }
                touchActive = true
                holdFired = false
                isHolding = true
                withAnimation(.linear(duration: holdDuration)) { holdProgress = 1 }

                holdTimer?.invalidate()
                holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
                    Task { @MainActor in
                        holdFired = true
                        isHolding = false
                        holdProgress = 0
                        guard store.state.newMatchCountdownDeadline == nil else { return }
                        WKInterfaceDevice.current().play(.retry)
                        store.resetForHoldGesture()
                    }
                }
            }
            .onEnded { value in
                touchActive = false
                holdTimer?.invalidate()
                holdTimer = nil
                let firedHold = holdFired

                withAnimation(.easeOut(duration: 0.15)) {
                    isHolding = false
                    holdProgress = 0
                }

                guard !firedHold else { return }

                let dx = value.translation.width
                let dy = value.translation.height
                let distance = (dx * dx + dy * dy).squareRoot()

                if dx < -30 && abs(dy) < 40 && distance > 24 {
                    performUndo()
                } else if distance < 16 {
                    handleTap()
                }
                // Anything else (a longer or more diagonal drag that's
                // neither a clean tap nor a clean left swipe) is ignored —
                // better to do nothing than guess wrong mid-rally.
            }
    }

    /// Single tap scores Team A; a second tap arriving within the double-tap
    /// window upgrades it to a Team B point instead.
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

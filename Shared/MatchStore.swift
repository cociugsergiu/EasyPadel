import Foundation
import Combine

/// Single source of truth for the current match, shared (as source code) between
/// the iPhone and Watch app targets. Each device keeps its own local copy so the
/// Watch app keeps working even when it's out of range of the phone, and the two
/// reconcile via ConnectivitySync whenever they're reachable.
@MainActor
final class MatchStore: ObservableObject {
    /// How many matches can be played before Full Access is required.
    static let freeMatchLimit = 5

    @Published private(set) var state: MatchState
    @Published private(set) var canUndo = false
    @Published private(set) var matchHistory: [MatchRecord] = []
    @Published var showPaywall = false

    let purchases = PurchaseManager()

    private let defaultsKey = "PadelPoint.matchState"
    private let historyDefaultsKey = "PadelPoint.matchHistory"
    private let connectivity = ConnectivitySync()
    private var history: [MatchState] = []
    private let maxHistory = 20
    private let maxHistoryRecords = 50
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(MatchState.self, from: data) {
            state = saved
        } else {
            state = .initial
        }

        if let data = UserDefaults.standard.data(forKey: historyDefaultsKey),
           let saved = try? JSONDecoder().decode([MatchRecord].self, from: data) {
            matchHistory = saved
        }

        connectivity.onReceive = { [weak self] incoming in
            DispatchQueue.main.async {
                self?.merge(incoming)
            }
        }
        connectivity.onReceiveHistory = { [weak self] record in
            DispatchQueue.main.async {
                self?.addHistoryRecord(record, broadcast: false)
            }
        }
        connectivity.activate()

        // PurchaseManager is its own ObservableObject nested inside this
        // one — SwiftUI views observe `store`, not `store.purchases`
        // directly, and a nested ObservableObject's changes don't
        // propagate on their own. Without this forward, tapping Buy would
        // update `purchases.isPurchasing`/`errorMessage`/`isUnlocked`
        // internally but no view would ever redraw to show it.
        purchases.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func addPoint(for team: Team) {
        var new = state
        new.addPoint(for: team)
        apply(new)
    }

    /// Full reset — wipes the whole match including sets already won. Only
    /// for a deliberate "start over" action (post-win, or Settings).
    func resetMatch() {
        var new = state
        new.reset()
        apply(new)
    }

    /// Quick in-game reset — clears only the current set, leaving sets
    /// already won intact. This is what the hold gesture on iPhone/Watch does.
    func resetCurrentSet() {
        var new = state
        new.resetCurrentSet()
        apply(new)
    }

    /// What the hold-to-reset gesture should do. Once a match is decided,
    /// clearing just the current set is meaningless — `winner` stays set,
    /// scoring stays locked out, and the hold gesture would look like it
    /// does nothing (this was exactly the bug on Watch, which has no
    /// separate "New Match" button to fall back on). So once there's a
    /// winner, the hold gesture starts a whole new match instead.
    func resetForHoldGesture() {
        if state.winner != nil {
            beginNewMatch(withCountdown: false)
        } else {
            resetCurrentSet()
        }
    }

    /// True once the free tier's match allowance is used up and Full Access
    /// hasn't been purchased. Checked before any new match starts.
    var hasReachedFreeLimit: Bool {
        state.totalMatchesCompleted >= Self.freeMatchLimit && !purchases.isUnlocked
    }

    /// The single entry point for starting a new match — every "New Match" /
    /// hold-to-reset-after-a-win action funnels through here so the free
    /// limit can't be bypassed by hitting one call site but not another.
    /// Presents the paywall instead of starting the match once the free
    /// allowance is used up.
    func beginNewMatch(withCountdown: Bool) {
        guard !hasReachedFreeLimit else {
            showPaywall = true
            return
        }
        if withCountdown {
            startNewMatchCountdown()
        } else {
            resetMatch()
        }
    }

    func setGoldenPoint(_ on: Bool) {
        var new = state
        new.goldenPoint = on
        new.updatedAt = Date()
        apply(new)
    }

    func setSetsToWin(_ count: Int) {
        var new = state
        new.setsToWin = count
        new.updatedAt = Date()
        apply(new)
    }

    func setSimpleScoring(_ on: Bool) {
        var new = state
        new.simpleScoring = on
        new.updatedAt = Date()
        apply(new)
    }

    func setTheme(_ id: String) {
        guard TeamTheme.theme(for: id).isUnlocked(matchesPlayed: state.matchesPlayed) else { return }
        var new = state
        new.themeID = id
        new.updatedAt = Date()
        apply(new)
    }

    func setTeamName(_ name: String, for team: Team) {
        var new = state
        if team == .a { new.nameA = name } else { new.nameB = name }
        new.updatedAt = Date()
        apply(new)
    }

    func resetMatchesPlayed() {
        var new = state
        new.resetMatchesPlayed()
        apply(new)
    }

    /// Starts a synced "new match starting in 3…2…1" countdown. Every
    /// device shows the same countdown almost instantly, since it's driven
    /// by this shared deadline rather than a per-device timer.
    func startNewMatchCountdown(seconds: TimeInterval = 3) {
        var new = state
        new.newMatchCountdownDeadline = Date().addingTimeInterval(seconds)
        new.updatedAt = Date()
        apply(new)
    }

    func cancelNewMatchCountdown() {
        guard state.newMatchCountdownDeadline != nil else { return }
        var new = state
        new.newMatchCountdownDeadline = nil
        new.updatedAt = Date()
        apply(new)
    }

    var currentTheme: TeamTheme {
        TeamTheme.theme(for: state.themeID)
    }

    /// Re-checks the paired device's last known state immediately, rather
    /// than waiting for a live push. Call this whenever a view appears, so
    /// e.g. opening the Watch app after changing something on the iPhone
    /// (while the Watch app wasn't running to receive the live push)
    /// reflects the latest settings right away instead of showing whatever
    /// was last saved locally until the next change syncs it.
    func refreshFromPairedDevice() {
        connectivity.checkForLatestContext()
    }

    /// Reverts the most recent local change (a point, a reset, a settings
    /// tweak) — meant mainly for undoing an accidental tap. Only undoes
    /// changes made on this device; an update that arrived from the paired
    /// device via WatchConnectivity is never pushed onto this history, so
    /// undo can't fight the other device's actions.
    func undo() {
        guard var previous = history.popLast() else { return }
        canUndo = !history.isEmpty
        // Stamp as "now" even though the content is older — merge() picks
        // whichever side has the newer `updatedAt`, so without this the
        // paired device would see an older timestamp and reject the undo
        // as stale, leaving the two devices out of sync.
        previous.updatedAt = Date()
        state = previous
        persist()
        connectivity.send(previous)
    }

    private func apply(_ new: MatchState) {
        // Only the device that actually scores the winning point takes this
        // branch (a state that arrives already-won via merge() below does
        // not), so exactly one device creates the record and broadcasts it
        // — the paired device receives that broadcast instead of also
        // independently detecting the same completion, which is what keeps
        // this from creating a duplicate entry on both sides.
        if state.winner == nil, let winner = new.winner {
            let record = MatchRecord(
                nameA: new.name(for: .a),
                nameB: new.name(for: .b),
                setsA: new.setsA,
                setsB: new.setsB,
                completedSets: new.completedSets,
                winner: winner
            )
            addHistoryRecord(record, broadcast: true)
        }

        history.append(state)
        if history.count > maxHistory { history.removeFirst() }
        canUndo = true
        state = new
        persist()
        connectivity.send(new)
    }

    private func addHistoryRecord(_ record: MatchRecord, broadcast: Bool) {
        guard !matchHistory.contains(where: { $0.id == record.id }) else { return }
        matchHistory.insert(record, at: 0)
        if matchHistory.count > maxHistoryRecords { matchHistory.removeLast() }
        persistHistory()
        if broadcast {
            connectivity.sendHistory(record)
        }
    }

    private func merge(_ incoming: MatchState) {
        guard incoming.updatedAt > state.updatedAt else { return }
        state = incoming
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(matchHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyDefaultsKey)
    }
}

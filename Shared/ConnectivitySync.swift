import Foundation
import WatchConnectivity

/// Keeps the iPhone and Watch apps' match state in sync via WatchConnectivity.
/// Uses `updateApplicationContext`, which always delivers only the latest
/// value (perfect fit for "current score", not an event log).
final class ConnectivitySync: NSObject, WCSessionDelegate {
    var onReceive: ((MatchState) -> Void)?
    var onReceiveHistory: ((MatchRecord) -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
        // receivedApplicationContext is a local cache the OS keeps in sync
        // regardless of live activation state, so this can catch a launch
        // where the delegate's activationDidCompleteWith(_:) doesn't (in
        // practice, launching cold sometimes missed the callback-based
        // check below, leaving the app briefly showing stale settings from
        // its own last local save until the next live push arrived).
        checkForLatestContext()
    }

    /// Re-pulls whatever the paired device's most recent state is, without
    /// waiting for a live push. Meant to be called again whenever this app
    /// becomes active (e.g. on appear), since a push that arrived while this
    /// device was backgrounded isn't guaranteed to have been processed yet.
    func checkForLatestContext() {
        guard let session,
              let data = session.receivedApplicationContext["state"] as? Data,
              let decoded = try? JSONDecoder().decode(MatchState.self, from: data) else { return }
        onReceive?(decoded)
    }

    func send(_ state: MatchState) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? session.updateApplicationContext(["state": data])
    }

    /// Sends one completed match as a queued delta via `transferUserInfo`,
    /// not `updateApplicationContext` — that mechanism only ever keeps the
    /// *latest* value per key, which is right for the live score but wrong
    /// here: each finished match is its own event, and transferUserInfo
    /// reliably delivers every one (even queuing until the paired device is
    /// reachable) instead of the newest just clobbering the last.
    func sendHistory(_ record: MatchRecord) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(record) else { return }
        session.transferUserInfo(["historyRecord": data])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["historyRecord"] as? Data,
              let record = try? JSONDecoder().decode(MatchRecord.self, from: data) else { return }
        onReceiveHistory?(record)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        checkForLatestContext()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["state"] as? Data,
              let decoded = try? JSONDecoder().decode(MatchState.self, from: data) else { return }
        onReceive?(decoded)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}

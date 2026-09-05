#if os(iOS)
import Foundation
import MultipeerConnectivity
import UIKit

/// Where this device currently stands relative to a "watch this match live"
/// session — at most one of these at a time (you're either running your own
/// match and optionally letting others watch, or watching someone else's;
/// never both, which keeps "who's actually in control" unambiguous).
enum SpectatorConnectionState: Equatable {
    case idle
    case hosting
    case browsing
    case connecting(hostName: String)
    case viewing(hostName: String)
}

/// Lets nearby devices mirror a live match over MultipeerConnectivity
/// (Bluetooth/local WiFi, no server, no accounts) — built for the exact
/// scenario this app is used in: teammates and opponents already standing
/// on the same court. Not meant for anyone who isn't physically nearby;
/// that would need a real backend relay instead.
@MainActor
final class MultipeerMatchSession: NSObject, ObservableObject {
    @Published private(set) var connectionState: SpectatorConnectionState = .idle
    @Published private(set) var discoveredHosts: [MCPeerID] = []
    @Published private(set) var connectedViewerNames: [String] = []

    /// Fires on the viewer's side whenever a fresh match snapshot arrives
    /// from the host.
    var onReceiveState: ((MatchState) -> Void)?

    private static let serviceType = "easypadel-match"

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)

    private lazy var session: MCSession = {
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    var isHosting: Bool { connectionState == .hosting }

    var isViewing: Bool {
        if case .viewing = connectionState { return true }
        return false
    }

    // MARK: Hosting (let others watch my match)

    func startHosting() {
        guard connectionState == .idle else { return }
        connectionState = .hosting
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session.disconnect()
        connectedViewerNames = []
        connectionState = .idle
    }

    /// Re-sends the current state to everyone already connected — used
    /// right when a new viewer joins, so they see the real score
    /// immediately instead of waiting for the next point to be scored.
    func broadcast(_ state: MatchState) {
        guard isHosting, !session.connectedPeers.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: Viewing (watch someone else's match)

    func startBrowsing() {
        guard connectionState == .idle else { return }
        connectionState = .browsing
        discoveredHosts = []
        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        discoveredHosts = []
        if connectionState == .browsing {
            connectionState = .idle
        }
    }

    func join(_ peer: MCPeerID) {
        guard let browser else { return }
        connectionState = .connecting(hostName: peer.displayName)
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    }

    /// Leaves a match being watched, or stops hosting one — whichever
    /// applies. Safe to call from either role, or from idle.
    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        discoveredHosts = []
        connectedViewerNames = []
        connectionState = .idle
    }
}

extension MultipeerMatchSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if self.isHosting {
                    self.connectedViewerNames = session.connectedPeers.map(\.displayName)
                } else if case .connecting = self.connectionState {
                    self.connectionState = .viewing(hostName: peerID.displayName)
                }
            case .notConnected:
                if self.isHosting {
                    self.connectedViewerNames = session.connectedPeers.map(\.displayName)
                } else if !self.isHosting && self.connectionState != .idle && self.connectionState != .browsing {
                    // The host ended the session (or connection dropped) —
                    // drop back to idle rather than getting stuck showing a
                    // "watching" state for a match that's no longer there.
                    self.connectionState = .idle
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let decoded = try? JSONDecoder().decode(MatchState.self, from: data) else { return }
        Task { @MainActor in
            self.onReceiveState?(decoded)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerMatchSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            // Anyone nearby who finds the match can watch — there's no
            // sensitive data in a padel score, so this skips a manual
            // "accept viewer?" prompt per person in favor of it just working.
            invitationHandler(self.isHosting, self.isHosting ? self.session : nil)
        }
    }
}

extension MultipeerMatchSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard !self.discoveredHosts.contains(peerID) else { return }
            self.discoveredHosts.append(peerID)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredHosts.removeAll { $0 == peerID }
        }
    }
}
#endif

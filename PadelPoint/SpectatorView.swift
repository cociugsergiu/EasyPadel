import SwiftUI
import MultipeerConnectivity

/// Entry point for "watch this match live" — host lets nearby devices
/// mirror the score, or join someone else's match as a read-only viewer.
/// Peer-to-peer over Bluetooth/local WiFi (MultipeerConnectivity), so this
/// only ever finds people actually nearby, on the same court — there's no
/// server, no accounts, and nothing to set up beforehand.
struct SpectatorView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch store.multipeer.connectionState {
                case .idle:
                    choiceView
                case .hosting:
                    hostingView
                case .browsing:
                    browsingView
                case .connecting(let hostName):
                    connectingView(hostName: hostName)
                case .viewing:
                    // Joining dismisses this sheet immediately (see
                    // startWatching below) — this case only briefly exists
                    // in between, so there's nothing meaningful to show.
                    EmptyView()
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Watch Together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.multipeer.connectionState) { _, newValue in
            if case .viewing = newValue {
                dismiss()
            }
        }
        .onDisappear {
            if case .browsing = store.multipeer.connectionState {
                store.stopBrowsingForMatches()
            }
        }
    }

    private var choiceView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gold)

            Text("Let teammates and opponents\non the court watch this match live")
                .multilineTextAlignment(.center)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    store.startHostingSpectators()
                } label: {
                    Text("Host This Match")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.gold, in: Capsule())
                        .foregroundStyle(.black)
                }

                Button {
                    store.startBrowsingForMatches()
                } label: {
                    Text("Watch a Nearby Match")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var hostingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .tint(Theme.gold)

            Text("Broadcasting Your Match")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if store.multipeer.connectedViewerNames.isEmpty {
                Text("Waiting for nearby devices to join…")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                VStack(spacing: 6) {
                    Text("\(store.multipeer.connectedViewerNames.count) watching")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                    ForEach(store.multipeer.connectedViewerNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            Spacer()

            Button {
                store.stopHostingSpectators()
            } label: {
                Text("Stop Sharing")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(Theme.teamA)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var browsingView: some View {
        VStack(spacing: 0) {
            if store.multipeer.discoveredHosts.isEmpty {
                Spacer()
                ProgressView()
                    .tint(Theme.gold)
                    .padding(.bottom, 12)
                Text("Looking for nearby matches…")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                List {
                    Section {
                        ForEach(store.multipeer.discoveredHosts, id: \.self) { peer in
                            Button {
                                store.joinMatch(peer)
                            } label: {
                                HStack {
                                    Image(systemName: "iphone")
                                        .foregroundStyle(Theme.gold)
                                    Text(peer.displayName)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                        }
                    } footer: {
                        Text("Tap a match to watch it live.")
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Button {
                store.stopBrowsingForMatches()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func connectingView(hostName: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(Theme.gold)
            Text("Connecting to \(hostName)…")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }
}

#Preview {
    SpectatorView().environmentObject(MatchStore())
}

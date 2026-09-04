import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("landscapeInfoStyle") private var infoStyleRaw = LandscapeInfoStyle.flash.rawValue
    @Binding var showStylePicker: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Golden Point", isOn: Binding(
                        get: { store.state.goldenPoint },
                        set: { store.setGoldenPoint($0) }
                    ))

                    Picker("Sets to Win", selection: Binding(
                        get: { store.state.setsToWin },
                        set: { store.setSetsToWin($0) }
                    )) {
                        Text("Best of 1").tag(1)
                        Text("Best of 3").tag(2)
                        Text("Best of 5").tag(3)
                    }

                    Toggle("Simple Scoring", isOn: Binding(
                        get: { store.state.simpleScoring },
                        set: { store.setSimpleScoring($0) }
                    ))
                } footer: {
                    Text("Golden Point: sudden death at 40-40 instead of advantage — how most padel clubs play. Sets to Win: how many sets take the match. Simple Scoring: points shown as 0-1-2-3 (Americano-style) instead of 0-15-30-40.")
                }

                Section {
                    TextField("Team A", text: Binding(
                        get: { store.state.nameA },
                        set: { store.setTeamName($0, for: .a) }
                    ))
                    TextField("Team B", text: Binding(
                        get: { store.state.nameB },
                        set: { store.setTeamName($0, for: .b) }
                    ))
                } header: {
                    Text("Team Names")
                } footer: {
                    Text("Shown throughout the app in place of \"Team A\" / \"Team B\".")
                }

                Section {
                    Button {
                        dismiss()
                        showStylePicker = true
                    } label: {
                        HStack {
                            Text("Background Style")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Picker("Landscape Mode Score", selection: $infoStyleRaw) {
                        Text("Flash Overlay").tag(LandscapeInfoStyle.flash.rawValue)
                        Text("Score Badge").tag(LandscapeInfoStyle.badge.rawValue)
                    }
                } footer: {
                    Text("Flash Overlay: a scoreboard graphic flashes on screen every 8 seconds, like a broadcast score bug. Score Badge: a compact scoreboard stays on screen at all times.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView(showStylePicker: .constant(false)).environmentObject(MatchStore())
}

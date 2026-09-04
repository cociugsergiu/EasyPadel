import SwiftUI

/// Concise list of completed matches — date, final score, set-by-set
/// breakdown — styled to match the rest of the app (silver captions, team
/// colors, rounded numerals) rather than a default system list.
struct MatchHistoryView: View {
    @EnvironmentObject private var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClearAll = false

    var body: some View {
        NavigationStack {
            Group {
                if store.matchHistory.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.25))
                        Text("No matches yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(store.matchHistory) { record in
                                MatchHistoryRow(record: record, theme: store.currentTheme)
                                    .listRowBackground(Color.clear)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    store.deleteHistoryRecord(store.matchHistory[index])
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)

                        Button(role: .destructive) {
                            confirmingClearAll = true
                        } label: {
                            Text("Clear All Matches")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.teamA.opacity(0.85))
                        }
                        .padding(.vertical, 14)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Match History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Clear all match history? This also resets your trophy progress — it won't affect your free-match count.",
                isPresented: $confirmingClearAll,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    store.clearAllHistory()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct MatchHistoryRow: View {
    let record: MatchRecord
    let theme: TeamTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                .silverLabel(size: 10, tracking: 0.5)

            HStack(spacing: 6) {
                Text(record.nameA)
                    .foregroundStyle(record.winner == .a ? theme.color(for: .a) : .white.opacity(0.55))
                    .fontWeight(record.winner == .a ? .bold : .regular)
                    .lineLimit(1)
                Text("\(record.setsA)")
                    .foregroundStyle(.white.opacity(0.9))
                Text(":")
                    .foregroundStyle(.white.opacity(0.3))
                Text("\(record.setsB)")
                    .foregroundStyle(.white.opacity(0.9))
                Text(record.nameB)
                    .foregroundStyle(record.winner == .b ? theme.color(for: .b) : .white.opacity(0.55))
                    .fontWeight(record.winner == .b ? .bold : .regular)
                    .lineLimit(1)
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))

            if !record.completedSets.isEmpty {
                Text(record.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ·  "))
                    .silverLabel(size: 11, tracking: 0.5)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    MatchHistoryView().environmentObject(MatchStore())
}

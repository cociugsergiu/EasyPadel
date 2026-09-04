import SwiftUI

/// Compact watch version of match history — one line per match, most recent
/// first, styled to match the rest of the app.
struct WatchMatchHistoryView: View {
    @EnvironmentObject private var store: MatchStore
    @State private var confirmingClearAll = false

    var body: some View {
        Group {
            if store.matchHistory.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No matches yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.matchHistory) { record in
                        WatchMatchHistoryRow(record: record, theme: store.currentTheme)
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.deleteHistoryRecord(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }

                    Button(role: .destructive) {
                        confirmingClearAll = true
                    } label: {
                        Text("Clear All Matches")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.teamA.opacity(0.85))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .confirmationDialog(
            "Clear all match history? This also resets trophy progress.",
            isPresented: $confirmingClearAll,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                store.clearAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct WatchMatchHistoryRow: View {
    let record: MatchRecord
    let theme: TeamTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(record.date.formatted(date: .numeric, time: .shortened))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            HStack(spacing: 4) {
                Text(record.nameA)
                    .foregroundStyle(record.winner == .a ? theme.color(for: .a) : .white.opacity(0.55))
                Text("\(record.setsA)-\(record.setsB)")
                    .foregroundStyle(.white.opacity(0.9))
                Text(record.nameB)
                    .foregroundStyle(record.winner == .b ? theme.color(for: .b) : .white.opacity(0.55))
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            if !record.completedSets.isEmpty {
                Text(record.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: " · "))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        WatchMatchHistoryView().environmentObject(MatchStore())
    }
}

import Foundation

/// A snapshot of one completed match, kept after the live score resets.
/// Sent between devices as a one-off delta (see ConnectivitySync.sendHistory)
/// rather than folded into the constantly-changing live MatchState, so
/// scoring a point never has to re-transmit the whole match history.
struct MatchRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let nameA: String
    let nameB: String
    let setsA: Int
    let setsB: Int
    let completedSets: [SetScore]
    let winner: Team

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        nameA: String,
        nameB: String,
        setsA: Int,
        setsB: Int,
        completedSets: [SetScore],
        winner: Team
    ) {
        self.id = id
        self.date = date
        self.nameA = nameA
        self.nameB = nameB
        self.setsA = setsA
        self.setsB = setsB
        self.completedSets = completedSets
        self.winner = winner
    }

    func name(for team: Team) -> String {
        team == .a ? nameA : nameB
    }

    func sets(for team: Team) -> Int {
        team == .a ? setsA : setsB
    }
}

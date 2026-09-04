import SwiftUI

/// A selectable color pairing for the two teams. The first three are always
/// available; the rest unlock as lifetime matches-played milestones are hit.
struct TeamTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let colorA: Color
    let colorB: Color
    let unlockMatches: Int

    func color(for team: Team) -> Color {
        team == .a ? colorA : colorB
    }

    func isUnlocked(matchesPlayed: Int) -> Bool {
        matchesPlayed >= unlockMatches
    }

    static let classic = TeamTheme(
        id: "classic", name: "Classic",
        colorA: Theme.teamA, colorB: Theme.teamB,
        unlockMatches: 0
    )

    static let all: [TeamTheme] = [
        classic,
        TeamTheme(
            id: "ocean", name: "Ocean & Sand",
            colorA: Color(red: 0.20, green: 0.45, blue: 0.85),
            colorB: Color(red: 0.85, green: 0.68, blue: 0.42),
            unlockMatches: 0
        ),
        TeamTheme(
            id: "orchid", name: "Orchid & Sage",
            colorA: Color(red: 0.55, green: 0.20, blue: 0.45),
            colorB: Color(red: 0.45, green: 0.60, blue: 0.40),
            unlockMatches: 0
        ),
        TeamTheme(
            id: "bronze", name: "Bronze",
            colorA: Color(red: 0.72, green: 0.45, blue: 0.22),
            colorB: Color(red: 0.32, green: 0.22, blue: 0.16),
            unlockMatches: 5
        ),
        TeamTheme(
            id: "silver", name: "Silver & Emerald",
            colorA: Color(red: 0.76, green: 0.79, blue: 0.82),
            colorB: Color(red: 0.09, green: 0.42, blue: 0.32),
            unlockMatches: 10
        ),
        TeamTheme(
            id: "gold", name: "Gold & Garnet",
            colorA: Color(red: 0.85, green: 0.66, blue: 0.18),
            colorB: Color(red: 0.53, green: 0.10, blue: 0.16),
            unlockMatches: 20
        )
    ]

    static func theme(for id: String) -> TeamTheme {
        all.first { $0.id == id } ?? classic
    }
}

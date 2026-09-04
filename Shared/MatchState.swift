import Foundation

enum Team: String, Codable {
    case a, b

    var other: Team { self == .a ? .b : .a }
}

struct SetScore: Codable, Equatable {
    var gamesA: Int
    var gamesB: Int
}

/// Pure value type holding all padel match state. Scoring rules follow standard
/// tennis-style padel scoring: games to 4 points (win by 2, or "golden point"
/// sudden death at 40-40 when enabled), sets to 6 games (win by 2) with a
/// tiebreak at 6-6, match to 2 sets.
struct MatchState: Codable, Equatable {
    var pointsA = 0
    var pointsB = 0
    var gamesA = 0
    var gamesB = 0
    var setsA = 0
    var setsB = 0
    var completedSets: [SetScore] = []

    var isTiebreak = false
    var tiebreakA = 0
    var tiebreakB = 0

    var goldenPoint = true
    var setsToWin = 2
    var simpleScoring = false
    var themeID = TeamTheme.classic.id
    var matchesPlayed = 0
    var nameA = "Team A"
    var nameB = "Team B"

    var servingTeam: Team = .a
    var winner: Team?

    /// When set, a "start new match" countdown is in progress, ending at
    /// this wall-clock deadline. Synced like everything else, so pressing
    /// the button on one device shows the same countdown on the other
    /// almost instantly. `nil` after it completes or is cancelled.
    var newMatchCountdownDeadline: Date?

    var updatedAt = Date.distantPast

    static let initial = MatchState()
}

extension MatchState {
    var isDeuce: Bool {
        !isTiebreak && pointsA >= 3 && pointsB >= 3 && pointsA == pointsB
    }

    /// True once any real progress has been made on an undecided match —
    /// used to detect "a match just started" (false → true) and "a match
    /// just ended, one way or another" (true → false), whether that's a
    /// natural win or the player abandoning it via a full reset. Drives the
    /// Watch's automatic workout start/stop.
    var isInProgress: Bool {
        winner == nil && (
            pointsA > 0 || pointsB > 0 ||
            gamesA > 0 || gamesB > 0 ||
            setsA > 0 || setsB > 0 ||
            !completedSets.isEmpty
        )
    }

    func points(for team: Team) -> Int { team == .a ? pointsA : pointsB }
    func games(for team: Team) -> Int { team == .a ? gamesA : gamesB }
    func sets(for team: Team) -> Int { team == .a ? setsA : setsB }
    func tiebreakPoints(for team: Team) -> Int { team == .a ? tiebreakA : tiebreakB }

    func name(for team: Team) -> String {
        let raw = team == .a ? nameA : nameB
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (team == .a ? "Team A" : "Team B") : trimmed
    }

    func pointDisplay(for team: Team) -> String {
        if isTiebreak {
            return String(tiebreakPoints(for: team))
        }
        let mine = points(for: team)
        let theirs = points(for: team.other)
        let labels = simpleScoring ? ["0", "1", "2", "3"] : ["0", "15", "30", "40"]
        let topLabel = labels[3]

        if mine < 3 || theirs < 3 {
            return labels[min(mine, 3)]
        }
        if goldenPoint {
            return topLabel
        }
        if mine == theirs { return topLabel }
        return mine > theirs ? "AD" : topLabel
    }

    mutating func addPoint(for team: Team) {
        guard winner == nil else { return }
        if isTiebreak {
            addTiebreakPoint(for: team)
        } else {
            addGamePoint(for: team)
        }
        updatedAt = Date()
    }

    /// Full reset: wipes the whole match, including sets already won. Used to
    /// start a brand new match (post-win "New Match", or the explicit
    /// "Start New Match" action in Settings) — never by the in-game hold
    /// gesture, which should only undo the current set.
    mutating func reset() {
        let settings = (goldenPoint, setsToWin, simpleScoring, themeID, matchesPlayed, nameA, nameB)
        self = .initial
        (goldenPoint, setsToWin, simpleScoring, themeID, matchesPlayed, nameA, nameB) = settings
        updatedAt = Date()
    }

    /// Clears just the current set's points/games (and tiebreak, if any),
    /// leaving sets already won intact. This is what the quick hold-to-reset
    /// gesture on iPhone/Watch performs — an "undo a mis-tap" action, not a
    /// full restart.
    mutating func resetCurrentSet() {
        pointsA = 0
        pointsB = 0
        gamesA = 0
        gamesB = 0
        isTiebreak = false
        tiebreakA = 0
        tiebreakB = 0
        updatedAt = Date()
    }

    /// Resets lifetime match count (and re-locks any theme that's no longer
    /// earned) without touching the score in progress.
    mutating func resetMatchesPlayed() {
        matchesPlayed = 0
        if !TeamTheme.theme(for: themeID).isUnlocked(matchesPlayed: 0) {
            themeID = TeamTheme.classic.id
        }
        updatedAt = Date()
    }

    private mutating func addGamePoint(for team: Team) {
        if team == .a { pointsA += 1 } else { pointsB += 1 }

        let mine = points(for: team)
        let theirs = points(for: team.other)

        let winsGame: Bool
        if goldenPoint {
            winsGame = mine >= 4 && mine > theirs
        } else {
            winsGame = mine >= 4 && (mine - theirs) >= 2
        }

        if winsGame {
            completeGame(winner: team)
        }
    }

    private mutating func completeGame(winner team: Team) {
        pointsA = 0
        pointsB = 0
        if team == .a { gamesA += 1 } else { gamesB += 1 }
        servingTeam = servingTeam.other

        if gamesA >= 6 && gamesA - gamesB >= 2 {
            completeSet(winner: .a)
        } else if gamesB >= 6 && gamesB - gamesA >= 2 {
            completeSet(winner: .b)
        } else if gamesA == 7 {
            completeSet(winner: .a)
        } else if gamesB == 7 {
            completeSet(winner: .b)
        } else if gamesA == 6 && gamesB == 6 {
            isTiebreak = true
        }
    }

    private mutating func addTiebreakPoint(for team: Team) {
        if team == .a { tiebreakA += 1 } else { tiebreakB += 1 }

        let mine = tiebreakPoints(for: team)
        let theirs = tiebreakPoints(for: team.other)
        guard mine >= 7 && (mine - theirs) >= 2 else { return }

        if team == .a { gamesA += 1 } else { gamesB += 1 }
        isTiebreak = false
        tiebreakA = 0
        tiebreakB = 0
        completeSet(winner: team)
    }

    private mutating func completeSet(winner team: Team) {
        completedSets.append(SetScore(gamesA: gamesA, gamesB: gamesB))
        gamesA = 0
        gamesB = 0
        if team == .a { setsA += 1 } else { setsB += 1 }

        if setsA == setsToWin || setsB == setsToWin {
            self.winner = setsA == setsToWin ? .a : .b
            matchesPlayed += 1
        }
    }
}

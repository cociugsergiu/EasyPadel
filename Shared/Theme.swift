import SwiftUI

/// How the landscape iPhone/iPad layout surfaces sets/games info: a
/// periodic full-screen flash, or a small always-on badge up top.
enum LandscapeInfoStyle: String {
    case flash
    case badge
}

enum Theme {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let teamA = Color(red: 0.93, green: 0.44, blue: 0.35)   // warm coral
    static let teamB = Color(red: 0.11, green: 0.60, blue: 0.58)   // deep teal
    static let gold = Color(red: 0.83, green: 0.69, blue: 0.35)    // accent
    static let success = Color(red: 0.38, green: 0.68, blue: 0.45) // unlocked / confirmation
    static let ink = Color.white

    static func teamColor(_ team: Team) -> Color {
        team == .a ? teamA : teamB
    }
}

/// A subtle, "brushed silver" caption style for optional helper labels
/// (explanatory text that pros can hide via the labels toggle). Barely-there
/// gradient + soft glow instead of flat grey, so it reads as a deliberate
/// finish rather than a dimmed/disabled state.
struct SilverLabel: ViewModifier {
    var size: CGFloat = 10
    var tracking: CGFloat = 1.5

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold))
            .tracking(tracking)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.35),
                        Color.white.opacity(0.85),
                        Color.white.opacity(0.35)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: .white.opacity(0.3), radius: 1.5)
    }
}

extension View {
    func silverLabel(size: CGFloat = 10, tracking: CGFloat = 1.5) -> some View {
        modifier(SilverLabel(size: size, tracking: tracking))
    }
}

/// A soft, warm wash across the whole screen — lighter through the middle,
/// falling off darker at the top and bottom edges, like an overhead court
/// light. Meant to sit as a non-interactive top layer over everything else,
/// blended so it reads as ambient lighting/texture rather than a visible
/// gradient shape.
struct CourtLighting: View {
    var intensity: Double = 1.0

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.22 * intensity), location: 0),
                .init(color: Color(red: 1.0, green: 0.88, blue: 0.62).opacity(0.10 * intensity), location: 0.5),
                .init(color: .black.opacity(0.22 * intensity), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Makes text read as pressed into the surface rather than sitting on top of
/// it — a soft highlight catching the light from the upper-left, and a
/// darker shadow falling to the lower-right, like a character embossed into
/// felt. Two plain `.shadow()` passes, so it stays cheap at any text size.
struct EngravedText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .white.opacity(0.22), radius: 0.5, x: -1, y: -1)
            .shadow(color: .black.opacity(0.55), radius: 1.5, x: 1.5, y: 2)
    }
}

extension View {
    func engraved() -> some View {
        modifier(EngravedText())
    }
}

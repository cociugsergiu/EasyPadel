import SwiftUI

/// A compact bottom panel over the live score screen — tapping a swatch
/// applies it immediately so the score screen behind updates live, letting
/// the player compare a few options in place rather than committing on a
/// separate settings page. Replaces the old full-page style picker.
struct BackgroundStylePicker: View {
    @EnvironmentObject private var store: MatchStore
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BACKGROUND STYLE")
                    .silverLabel(size: 11, tracking: 2)
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 26, height: 26)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(TeamTheme.all) { theme in
                        swatch(theme)
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 30)
        }
        .background(.black.opacity(0.9), in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = false
        }
    }

    @ViewBuilder
    private func swatch(_ theme: TeamTheme) -> some View {
        let unlocked = theme.isUnlocked(matchesPlayed: store.state.matchesPlayed)
        let selected = store.state.themeID == theme.id

        Button {
            guard unlocked else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                store.setTheme(theme.id)
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Rectangle().fill(theme.colorA)
                    Rectangle().fill(theme.colorB)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(selected ? Theme.gold : .white.opacity(0.15), lineWidth: selected ? 2.5 : 1)
                )
                .overlay {
                    if !unlocked {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(.black.opacity(0.55))
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.85))
                            )
                    }
                }

                Text(unlocked ? theme.name : "\(theme.unlockMatches) matches")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(unlocked ? .white.opacity(0.8) : .white.opacity(0.4))
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.background.ignoresSafeArea()
        BackgroundStylePicker(isPresented: .constant(true))
            .environmentObject(MatchStore())
    }
}

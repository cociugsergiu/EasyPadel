import SwiftUI

/// Press-and-hold reset control with a radial progress ring, mirroring the
/// hold-to-reset gesture on the Watch app so the interaction feels consistent.
struct HoldToResetButton: View {
    let onReset: () -> Void

    @State private var progress: CGFloat = 0
    @State private var justReset = false
    @State private var fillTimer: Timer?
    @State private var pressStarted: Date?

    private let holdDuration: Double = 1.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .rotationEffect(.degrees(justReset ? -360 : 0))
        }
        .frame(width: 34, height: 34)
        .contentShape(Circle())
        // Progress is driven by a manual timer sampling elapsed press time,
        // not by a `withAnimation(.linear(duration: holdDuration))` that
        // then needs to be "redirected" back to 0 on release. Retargeting an
        // in-flight long animation like that was unreliable in practice — a
        // short tap could visibly fill the ring as if a hold had completed,
        // even though `onReset` never actually fired. Sampling actual
        // elapsed time and stopping the timer immediately on release makes
        // the ring's fill amount always match how long the press really
        // lasted, with no animation to interrupt.
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 50) {
            fillTimer?.invalidate()
            fillTimer = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.4)) { justReset = true }
            onReset()
            progress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                justReset = false
            }
        } onPressingChanged: { pressing in
            if pressing {
                let start = Date()
                pressStarted = start
                fillTimer?.invalidate()
                fillTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
                    let elapsed = Date().timeIntervalSince(start)
                    progress = min(CGFloat(elapsed / holdDuration), 1)
                    if elapsed >= holdDuration { timer.invalidate() }
                }
            } else {
                fillTimer?.invalidate()
                fillTimer = nil
                if progress > 0 {
                    withAnimation(.easeOut(duration: 0.15)) { progress = 0 }
                }
            }
        }
    }
}

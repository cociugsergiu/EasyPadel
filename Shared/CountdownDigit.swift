import SwiftUI

/// Ticks down from a shared, wall-clock deadline (not a local timer count),
/// so every device watching the same synced `deadline` shows the same
/// number at essentially the same moment regardless of which device
/// started the countdown. Calls `onComplete` exactly once, when reached.
struct CountdownDigit: View {
    let deadline: Date
    var fontSize: CGFloat = 80
    let onComplete: () -> Void

    @State private var count: Int = 0
    @State private var timer: Timer?
    @State private var completed = false

    var body: some View {
        Text("\(max(count, 0))")
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Theme.gold)
            .id(count)
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                tick()
                start()
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }

    private func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            tick()
        }
    }

    private func tick() {
        let remaining = deadline.timeIntervalSinceNow
        let newCount = max(0, Int(remaining.rounded(.up)))
        if newCount != count {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                count = newCount
            }
        }
        if remaining <= 0, !completed {
            completed = true
            timer?.invalidate()
            timer = nil
            onComplete()
        }
    }
}

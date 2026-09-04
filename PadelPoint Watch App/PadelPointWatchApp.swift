import SwiftUI

@main
struct PadelPointWatchApp: App {
    @StateObject private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(store)
        }
    }
}

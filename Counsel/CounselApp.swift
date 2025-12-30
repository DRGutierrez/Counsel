import SwiftUI
import SwiftData

@main
struct CounselApp: App {
    init() {
        // Starts StoreKit listeners + entitlement refresh.
        SubscriptionManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [HistoryRecord.self])
    }
}

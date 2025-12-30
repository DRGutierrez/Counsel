import SwiftUI
import SwiftData

@main
struct CounselApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [HistoryRecord.self])
    }
}

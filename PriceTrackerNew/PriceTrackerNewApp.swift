import SwiftUI
import SwiftData

@main
struct PriceTrackerNewApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Product.self])
        // 🚨 关键：使用 App Group ID 确保数据跨进程共享
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.ahazyc.PriceTracker")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

import SwiftUI
import SwiftData

@main
struct PriceTrackerNewApp: App {
    init() {
        print("🚀 [PRICETRACKER] Starting...")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Product.self])
        let appGroup = "group.ahazyc.PriceTracker"
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroup)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [SwiftData] SUCCESS: App Group container ready.")
            return container
        } catch {
            print("❌ [SwiftData] ERROR: App Group failed (\(error.localizedDescription)). Cleaning up...")
            
            // Cleanup attempt: Try local storage if App Group fails
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                print("⚠️ [SwiftData] FALLBACK: Using local storage.")
                return container
            } catch {
                print("🚨 [SwiftData] FATAL: All storage failed. Using Memory.")
                return try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
